defmodule Aesir.ZoneServer.Integration.ItemStatBuffsTest do
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
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @items [
    {12284,
     "sc_start SC_INCINT,5400000,8; sc_start SC_INCVIT,5400000,4; sc_start SC_INCDEX,5400000,6; sc_start SC_MATKPOTION,5400000,40;",
     %{int: 8, vit: 4, dex: 6, matk: 40}, 5_400_000},
    {12283,
     "sc_start SC_INCSTR,5400000,8; sc_start SC_INCDEX,5400000,4; sc_start SC_INCAGI,5400000,6; sc_start SC_ATKPOTION,5400000,32; sc_start SC_INCFLEE,5400000,5;",
     %{str: 8, dex: 4, agi: 6, atk: 32, flee: 5}, 5_400_000},
    {12285,
     "sc_start SC_INCDEX,5400000,8; sc_start SC_INCLUK,5400000,4; sc_start SC_INCAGI,5400000,6; sc_start SC_ATKPOTION,5400000,24; sc_start SC_MATKPOTION,5400000,24;",
     %{dex: 8, luk: 4, agi: 6, atk: 24, matk: 24}, 5_400_000},
    {12338,
     "sc_start SC_INCSTR,180000,2; sc_start SC_INCINT,180000,2; sc_start SC_INCAGI,180000,2;",
     %{str: 2, int: 2, agi: 2}, 180_000},
    {12354,
     "specialeffect2 EF_ANGELUS; sc_start SC_INCMHPRATE,600000,3; sc_start SC_INCMSPRATE,600000,3; sc_start SC_INCHITRATE,600000,3; sc_start SC_INCCRI,600000,7;",
     %{max_hp_rate: 3, max_sp_rate: 3, hit_rate: 3, critical: 7}, 600_000},
    {13832, "sc_start SC_INCAGI,60000,5; sc_start SC_INCVIT,60000,5; sc_start SC_INCDEX,60000,5;",
     %{agi: 5, vit: 5, dex: 5}, 60_000},
    {13833, "sc_start SC_INCINT,60000,5; sc_start SC_INCVIT,60000,5; sc_start SC_INCDEX,60000,5;",
     %{int: 5, vit: 5, dex: 5}, 60_000},
    {13830, "sc_start SC_INCSTR,60000,5; sc_start SC_INCAGI,60000,5; sc_start SC_INCVIT,60000,5;",
     %{str: 5, agi: 5, vit: 5}, 60_000}
  ]
  @moduletag :capture_log

  setup do
    if GameMode.mode() == :renewal do
      Mimic.copy(Items)

      fixtures =
        Map.new(@items, fn {id, script, _, _} ->
          {:ok, item} = Items.by_id(id)
          {:ok, source} = Transpiler.transpile(script)
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

  test "item stat buffs preserve complete scripts, coexist with spell AGI and retain their lifecycle" do
    character = character()

    for {id, _, _, _} <- @items do
      {:ok, _} =
        Persistence.insert_item(character.id, %{
          nameid: id,
          amount: if(id in [12338, 13830], do: 2, else: 1),
          identify: 1
        })
    end

    session = start_player_session(character: character)
    on_exit(fn -> stop_session(session) end)
    base = get_player_state(session.pid).stats
    {:ok, table} = JobManagement.get_base_stats_for_level(:novice, 50)

    for {id, _, modifiers, duration} <- @items do
      held = Enum.map(StatusStorage.get_unit_statuses(:player, character.id), & &1.type)
      :ok = Interpreter.remove_statuses(:player, character.id, held)
      flush_packets()
      before_use = System.monotonic_time(:millisecond)
      use_item(session, id)
      after_use = System.monotonic_time(:millisecond)
      assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
      stats = get_player_state(session.pid).stats
      assert stats.modifiers.status_effects == modifiers
      refute StatusStorage.has_status?(:player, character.id, :sc_increaseagi)

      for entry <- StatusStorage.get_unit_statuses(:player, character.id) do
        assert entry.expires_at >= before_use + duration
        assert entry.expires_at <= after_use + duration
      end

      for stat <- [:agi, :vit] do
        assert Stats.get_effective_stat(stats, stat) ==
                 Stats.get_effective_stat(base, stat) + Map.get(modifiers, stat, 0)
      end

      vit = 10 + Map.get(modifiers, :vit, 0)
      raw_hp = table.hp * (1.0 + vit * 0.01)

      assert stats.derived_stats.max_hp ==
               trunc(raw_hp + trunc(raw_hp * Map.get(modifiers, :max_hp_rate, 0) / 100))

      assert stats.combat_stats.hit >= base.combat_stats.hit
      assert stats.derived_stats.aspd >= base.derived_stats.aspd

      if id == 12354 do
        assert stats.combat_stats.hit ==
                 base.combat_stats.hit + div(base.combat_stats.hit * 3, 100)

        assert :ok =
                 Interpreter.apply_status(:player, character.id, :sc_blind,
                   duration: 30_000,
                   bypass_resistance: true
                 )

        assert_eventually(fn ->
          blinded = get_player_state(session.pid).stats.combat_stats

          blinded.hit == stats.combat_stats.hit - div(stats.combat_stats.hit * 25, 100) and
            blinded.flee == stats.combat_stats.flee - div(stats.combat_stats.flee * 25, 100)
        end)
      end
    end

    agi = StatusStorage.get_status(:player, character.id, :sc_incagi)
    vit = StatusStorage.get_status(:player, character.id, :sc_incvit)
    use_item(session, 12338)
    assert StatusStorage.get_status(:player, character.id, :sc_incagi) == agi
    assert StatusStorage.get_status(:player, character.id, :sc_incvit) == vit

    use_item(session, 13830)
    refreshed = StatusStorage.get_status(:player, character.id, :sc_incagi)
    assert refreshed.val1 == 5
    assert refreshed.generation != agi.generation

    assert :ok =
             Interpreter.apply_status(:player, character.id, :sc_increaseagi,
               val1: 10,
               val2: 12,
               duration: 240_000
             )

    assert_eventually(fn ->
      stats = get_player_state(session.pid).stats
      Stats.get_effective_stat(stats, :agi) == Stats.get_effective_stat(base, :agi) + 17
    end)

    assert :ok = Dispel.dispel({:player, character.id})
    assert :ok = Interpreter.remove_on_death(:player, character.id)
    refute StatusStorage.has_status?(:player, character.id, :sc_increaseagi)
    assert %{val1: 5} = StatusStorage.get_status(:player, character.id, :sc_incagi)
    assert %{val1: 5} = StatusStorage.get_status(:player, character.id, :sc_incvit)
    assert Persistence.load_inventory(character.id) == []

    stop_session(session)
    saved = Repo.all(CharacterStatus)
    assert Enum.any?(saved, &(&1.status_type == "sc_incagi" and &1.val1 == 5))
    assert Enum.any?(saved, &(&1.status_type == "sc_incvit" and &1.val1 == 5))
    restored = start_player_session(character: Repo.get!(Character, character.id))
    on_exit(fn -> stop_session(restored) end)
    assert Repo.all(CharacterStatus) == []

    for status <- [:sc_incagi, :sc_incvit] do
      assert %{val1: 5} = StatusStorage.get_status(:player, character.id, status)

      StatusStorage.update_status(:player, character.id, status, fn entry ->
        %{entry | expires_at: System.monotonic_time(:millisecond) - 1}
      end)
    end

    StatusTickManager.force_tick()

    assert_eventually(fn ->
      stats = get_player_state(restored.pid).stats

      not StatusStorage.has_status?(:player, character.id, :sc_incagi) and
        not StatusStorage.has_status?(:player, character.id, :sc_incvit) and
        Stats.get_effective_stat(stats, :agi) == Stats.get_effective_stat(base, :agi) and
        stats.derived_stats.max_hp == base.derived_stats.max_hp
    end)
  end

  defp use_item(session, nameid) do
    {index, _} =
      Enum.find(get_player_state(session.pid).inventory, fn {_, item} -> item.nameid == nameid end)

    simulate_incoming_message(session.pid, %UseItem{index: PlayerState.client_index(index)})
    PlayerSession.get_state(session.pid)
  end

  defp stop_session(session) do
    if Process.alive?(session.pid), do: GenServer.stop(session.pid, :normal)
  end

  defp character do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "stat#{unique}",
        user_pass: "password",
        email: "stat#{unique}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "Stat#{unique}",
      class: 0,
      base_level: 50,
      job_level: 1,
      hp: 1,
      sp: 1,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
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
