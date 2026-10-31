defmodule Aesir.ZoneServer.Integration.HpSpPotionsTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.CharacterStatus
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @potions [
    {12422, "PROMOTE_HEALTH_RESERCH", 1, 1, 0, 830},
    {12423, "PROMOTE_HEALTH_RESERCH", 2, 2, 0, 1_830},
    {12424, "PROMOTE_HEALTH_RESERCH", 3, 5, 0, 2_830},
    {12425, "ENERGY_DRINK_RESERCH", 1, 0, 2, 4},
    {12426, "ENERGY_DRINK_RESERCH", 2, 0, 4, 9},
    {12427, "ENERGY_DRINK_RESERCH", 3, 0, 8, 14}
  ]
  @moduletag :capture_log

  setup do
    if GameMode.mode() == :renewal do
      Mimic.copy(Items)

      fixtures =
        Map.new(@potions, fn {id, status, size, hp, sp, _bonus} ->
          {:ok, item} = Items.by_id(id)

          {:ok, source} =
            Transpiler.transpile(
              "sc_start2 SC_#{status},500000,1,#{size}; percentheal #{hp},#{sp};"
            )

          {id, %{item | on_use: source}}
        end)

      stub(Items, :by_id, fn id ->
        case Map.fetch(fixtures, id) do
          {:ok, item} -> {:ok, item}
          :error -> call_original(Items, :by_id, [id])
        end
      end)

      ScriptCompiler.compile_all!(Enum.map(Items.all(), &Map.get(fixtures, &1.id, &1)))
    else
      ScriptCompiler.compile_all!()
    end

    on_exit(fn -> ScriptCompiler.compile_all!() end)
    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "six real potion scripts heal from the new maxima, replace sizes, persist and clamp on removal" do
    character = character()

    for {id, _, size, _, _, _} <- @potions do
      {:ok, _} =
        Persistence.insert_item(character.id, %{
          nameid: id,
          amount: if(size == 1, do: 2, else: 1),
          identify: 1
        })
    end

    session = start_player_session(character: character)
    on_exit(fn -> if Process.alive?(session.pid), do: GenServer.stop(session.pid, :normal) end)
    base = PlayerSession.get_state(session.pid).game_state.stats.derived_stats
    {:ok, table} = JobManagement.get_base_stats_for_level(:novice, 99)
    raw_sp = table.sp * 1.01

    for {id, name, size, hp, sp, bonus} <- @potions do
      before_stats = PlayerSession.get_state(session.pid).game_state.stats
      before_time = System.monotonic_time(:millisecond)
      flush_packets()
      use_item(session, id)
      after_time = System.monotonic_time(:millisecond)
      assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
      stats = PlayerSession.get_state(session.pid).game_state.stats
      status_id = String.to_existing_atom("sc_#{String.downcase(name)}")
      entry = StatusStorage.get_status(:player, character.id, status_id)
      assert %{val1: 1, val2: ^size, val3: ^bonus} = entry
      assert entry.expires_at >= before_time + 500_000
      assert entry.expires_at <= after_time + 500_000

      if hp > 0 do
        assert stats.derived_stats.max_hp == base.max_hp + bonus

        assert stats.current_state.hp ==
                 before_stats.current_state.hp + div(stats.derived_stats.max_hp * hp, 100)
      else
        assert stats.derived_stats.max_sp == trunc(raw_sp + raw_sp * bonus / 100)

        assert stats.current_state.sp ==
                 min(
                   before_stats.current_state.sp +
                     max(div(stats.derived_stats.max_sp * sp, 100), 1),
                   stats.derived_stats.max_sp
                 )
      end
    end

    boosted = PlayerSession.get_state(session.pid).game_state.stats.derived_stats
    PlayerSession.set_vitals(session.pid, hp: boosted.max_hp, sp: boosted.max_sp)
    use_item(session, 12422)
    use_item(session, 12425)
    stats = PlayerSession.get_state(session.pid).game_state.stats
    assert stats.derived_stats.max_hp == base.max_hp + 830
    assert stats.derived_stats.max_sp == trunc(raw_sp + raw_sp * 4 / 100)
    assert stats.current_state.hp == stats.derived_stats.max_hp
    assert stats.current_state.sp == stats.derived_stats.max_sp
    assert Persistence.load_inventory(character.id) == []

    GenServer.stop(session.pid, :normal)
    saved = Repo.all(CharacterStatus)
    assert Enum.any?(saved, &(&1.status_type == "sc_promote_health_reserch" and &1.val3 == 830))
    assert Enum.any?(saved, &(&1.status_type == "sc_energy_drink_reserch" and &1.val3 == 4))

    restored = start_player_session(character: Repo.get!(Character, character.id))
    on_exit(fn -> if Process.alive?(restored.pid), do: GenServer.stop(restored.pid, :normal) end)
    assert Repo.all(CharacterStatus) == []
    restored_stats = PlayerSession.get_state(restored.pid).game_state.stats
    assert restored_stats.current_state.hp == restored_stats.derived_stats.max_hp
    assert restored_stats.current_state.sp == restored_stats.derived_stats.max_sp

    assert %{val3: 830} =
             StatusStorage.get_status(:player, character.id, :sc_promote_health_reserch)

    assert %{val3: 4} = StatusStorage.get_status(:player, character.id, :sc_energy_drink_reserch)

    StatusStorage.update_status(:player, character.id, :sc_promote_health_reserch, fn entry ->
      %{entry | expires_at: System.monotonic_time(:millisecond) - 1}
    end)

    StatusTickManager.force_tick()

    assert_eventually(fn ->
      stats = PlayerSession.get_state(restored.pid).game_state.stats
      stats.current_state.hp == base.max_hp and stats.derived_stats.max_hp == base.max_hp
    end)

    assert :ok = Dispel.dispel({:player, character.id})

    assert_eventually(fn ->
      stats = PlayerSession.get_state(restored.pid).game_state.stats
      stats.current_state.sp == base.max_sp and stats.derived_stats.max_sp == base.max_sp
    end)
  end

  defp use_item(session, nameid) do
    {index, _} =
      Enum.find(PlayerSession.get_state(session.pid).game_state.inventory, fn {_i, item} ->
        item.nameid == nameid
      end)

    simulate_incoming_message(session.pid, %UseItem{index: PlayerState.client_index(index)})
    PlayerSession.get_state(session.pid)
  end

  defp character do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "potion#{unique}",
        user_pass: "password",
        email: "potion#{unique}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "Potion#{unique}",
      class: 0,
      base_level: 99,
      job_level: 1,
      hp: 1,
      sp: 1,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      save_map: "prontera",
      save_x: 150,
      save_y: 150
    })
    |> Repo.insert!()
  end
end
