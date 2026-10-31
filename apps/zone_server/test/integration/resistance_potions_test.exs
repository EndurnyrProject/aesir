defmodule Aesir.ZoneServer.Integration.ResistancePotionsTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.CharacterStatus
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.StatusChange
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @moduletag :capture_log

  setup do
    if GameMode.mode() == :renewal do
      Mimic.copy(Items)

      fixtures =
        Map.new(
          [
            {12118, "sc_start4 SC_ARMOR_ELEMENT_FIRE,1200000,-15,0,20,0;"},
            {12119, "sc_start4 SC_ARMOR_ELEMENT_WATER,1200000,20,0,0,-15;"}
          ],
          fn {id, script} ->
            {:ok, item} = Items.by_id(id)
            {:ok, source} = Transpiler.transpile(script)
            {id, %{item | on_use: source}}
          end
        )

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

  test "item ingress consumes potions, refreshes their icons and restores signed values on login" do
    character = character()
    {:ok, _} = Persistence.insert_item(character.id, %{nameid: 12118, amount: 2, identify: 1})
    {:ok, _} = Persistence.insert_item(character.id, %{nameid: 12119, amount: 1, identify: 1})
    session = start_player_session(character: character)
    on_exit(fn -> if Process.alive?(session.pid), do: GenServer.stop(session.pid, :normal) end)
    flush_packets()

    before = System.monotonic_time(:millisecond)
    use_item(session, 12118)
    after_use = System.monotonic_time(:millisecond)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)

    assert %StatusChange{efst: 910, on: true, val1: -15, val3: 20} =
             assert_packet_sent(StatusChange)

    fire = StatusStorage.get_status(:player, character.id, :sc_armor_element_fire)
    assert fire.expires_at >= before + 1_200_000
    assert fire.expires_at <= after_use + 1_200_000

    flush_packets()
    use_item(session, 12118)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
    refreshed = StatusStorage.get_status(:player, character.id, :sc_armor_element_fire)
    assert refreshed.generation != fire.generation
    assert %{val1: -15, val2: 0, val3: 20, val4: 0} = refreshed

    use_item(session, 12119)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
    assert ModifierCalculator.get_all_modifiers(:player, character.id).subele_water == 5
    assert Persistence.load_inventory(character.id) == []

    GenServer.stop(session.pid, :normal)
    saved = Repo.all(CharacterStatus)
    assert Enum.any?(saved, &(&1.status_type == "sc_armor_element_fire" and &1.val1 == -15))
    assert Enum.any?(saved, &(&1.status_type == "sc_armor_element_water" and &1.val4 == -15))

    restored = start_player_session(character: Repo.get!(Character, character.id))
    on_exit(fn -> if Process.alive?(restored.pid), do: GenServer.stop(restored.pid, :normal) end)
    assert Repo.all(CharacterStatus) == []

    assert %{val1: -15, val2: 0, val3: 20, val4: 0} =
             StatusStorage.get_status(:player, character.id, :sc_armor_element_fire)

    assert %{val1: 20, val2: 0, val3: 0, val4: -15} =
             StatusStorage.get_status(:player, character.id, :sc_armor_element_water)

    flush_packets()

    StatusStorage.update_status(:player, character.id, :sc_armor_element_fire, fn entry ->
      %{entry | expires_at: System.monotonic_time(:millisecond) - 1}
    end)

    StatusTickManager.force_tick()

    assert_eventually(fn ->
      StatusStorage.get_status(:player, character.id, :sc_armor_element_fire) == nil
    end)

    assert %StatusChange{efst: 910, on: false} = assert_packet_sent(StatusChange)
    assert ModifierCalculator.get_all_modifiers(:player, character.id).subele_water == 20
    assert StatusStorage.has_status?(:player, character.id, :sc_armor_element_water)
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
        userid: "resist#{unique}",
        user_pass: "password",
        email: "resist#{unique}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "Resist#{unique}",
      class: 0,
      base_level: 10,
      job_level: 1,
      hp: 100,
      max_hp: 100,
      sp: 11,
      max_sp: 11,
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
