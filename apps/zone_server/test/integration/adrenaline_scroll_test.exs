defmodule Aesir.ZoneServer.Integration.AdrenalineScrollTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.EquipItem
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.SkillEffect
  alias Aesir.Net.UnequipItem
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @scroll 12220
  @axes_and_mace [1301, 1351, 1501]
  @dagger 1201

  setup do
    {:ok, item} = Items.by_id(@scroll)

    {:ok, source} =
      Transpiler.transpile("""
      .@type = getiteminfo(getequipid(EQI_HAND_R),ITEMINFO_VIEW);
      if (.@type == W_1HAXE || .@type == W_2HAXE || .@type == W_MACE) {
        skilleffect "BS_ADRENALINE",0;
        sc_start SC_ADRENALINE,150000,5;
      }
      """)

    fixture = %{item | on_use: source}
    Mimic.copy(Items)

    stub(Items, :by_id, fn
      @scroll -> {:ok, fixture}
      id -> call_original(Items, :by_id, [id])
    end)

    ScriptCompiler.compile_all!([fixture])
    on_exit(fn -> ScriptCompiler.compile_all!() end)
    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "scroll ingress preserves the weapon gate, visual, direct status strength and refusal behavior" do
    character = character()

    {:ok, scroll} =
      Persistence.insert_item(character.id, %{nameid: @scroll, amount: 7, identify: 1})

    weapons =
      Map.new(@axes_and_mace ++ [@dagger], fn id ->
        {:ok, row} = Persistence.insert_item(character.id, %{nameid: id, amount: 1, identify: 1})
        {id, row.id}
      end)

    session = start_player_session(character: character)
    on_exit(fn -> if Process.alive?(session.pid), do: GenServer.stop(session.pid, :normal) end)

    for weapon <- @axes_and_mace do
      equip(session.pid, weapons[weapon])
      use_scroll(session.pid, scroll.id)
      assert %SkillEffect{skill_id: 111, level: 0} = assert_packet_sent(SkillEffect)
      entry = StatusStorage.get_status(:player, character.id, :sc_adrenaline)
      assert entry.source_id == character.id
      assert entry.val1 == 5
      assert entry.val2 == 0
      assert entry.val3 == 200
      assert entry.expires_at - entry.started_at == 165_000

      expected = if GameMode.mode() == :renewal, do: %{aspd: 7, hit: 20}, else: %{aspd_rate: 20}
      assert get_player_state(session.pid).stats.modifiers.status_effects == expected
    end

    equip(session.pid, weapons[@dagger])
    refute StatusStorage.has_status?(:player, character.id, :sc_adrenaline)
    use_scroll(session.pid, scroll.id)
    assert collect_packets_of_type(SkillEffect) == []

    simulate_incoming_message(session.pid, %UnequipItem{
      index: PlayerState.client_index(index(session.pid, weapons[@dagger]))
    })

    PlayerSession.get_state(session.pid)
    use_scroll(session.pid, scroll.id)
    refute StatusStorage.has_status?(:player, character.id, :sc_adrenaline)
    assert collect_packets_of_type(SkillEffect) == []

    equip(session.pid, weapons[1301])

    for blocker <- [:sc_quagmire, :sc_decreaseagi] do
      assert :ok =
               PlayerSession.apply_status(session.pid, blocker,
                 val1: 1,
                 duration: 30_000,
                 bypass_resistance: true
               )

      use_scroll(session.pid, scroll.id)
      assert %SkillEffect{skill_id: 111, level: 0} = assert_packet_sent(SkillEffect)
      refute StatusStorage.has_status?(:player, character.id, :sc_adrenaline)
      PlayerSession.remove_status(session.pid, blocker)
    end

    refute Enum.any?(Persistence.load_inventory(character.id), &(&1.nameid == @scroll))
  end

  defp equip(pid, row_id) do
    simulate_incoming_message(pid, %EquipItem{
      index: PlayerState.client_index(index(pid, row_id)),
      position: 2
    })

    PlayerSession.get_state(pid)
  end

  defp use_scroll(pid, row_id) do
    flush_packets()
    simulate_incoming_message(pid, %UseItem{index: PlayerState.client_index(index(pid, row_id))})
    PlayerSession.get_state(pid)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
  end

  defp index(pid, row_id) do
    {index, _item} =
      Enum.find(get_player_state(pid).inventory, fn {_, item} -> item.id == row_id end)

    index
  end

  defp character do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "scroll#{unique}",
        user_pass: "password",
        email: "scroll#{unique}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "Scroll#{unique}",
      class: 10,
      sex: "M",
      base_level: 99,
      job_level: 50,
      hp: 500,
      sp: 500,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      learned_skills: %{"105" => 1},
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
