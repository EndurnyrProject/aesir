defmodule Aesir.ZoneServer.Integration.EquipmentQueryIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.EquipItem
  alias Aesir.Net.EquipResult
  alias Aesir.Net.UnequipItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @provider 9_920_001
  @sword 9_920_002
  @bow 9_920_003

  setup do
    {:ok, program} =
      Transpiler.transpile_equip("""
      bonus bStr,getequiprefinerycnt(EQI_HAND_R);
      if (getiteminfo(getequipid(EQI_HAND_R),ITEMINFO_VIEW) == W_1HSWORD)
        bonus bHit,5;
      """)

    definitions = %{
      @provider => definition(@provider, :armor, locations: [:head_top], on_equip: program),
      @sword =>
        definition(@sword, :weapon,
          locations: [:right_hand],
          subtype: :one_handed_sword,
          weapon_level: 1
        ),
      @bow => definition(@bow, :weapon, locations: [:both_hand], subtype: :bow, weapon_level: 1)
    }

    stub(ItemManagement, :get_item_by_id, fn id ->
      case Map.fetch(definitions, id) do
        {:ok, definition} -> {:ok, definition}
        :error -> call_original(ItemManagement, :get_item_by_id, [id])
      end
    end)

    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "equip, weapon replacement and unequip refresh another item's slot queries" do
    character = insert_character()
    seed_item(character.id, @provider, 256, 9)
    sword = seed_item(character.id, @sword, 0, 7)
    bow = seed_item(character.id, @bow, 0, 3)
    session = start_player_session(character: character, map_name: "prontera")
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)

    assert query_bonuses(session.pid) == {0, 0}

    request_equip(session.pid, sword.id, 2)
    assert %EquipResult{result: 0} = assert_packet_sent(EquipResult)
    assert query_bonuses(session.pid) == {7, 5}

    request_equip(session.pid, bow.id, 34)
    assert %EquipResult{result: 0} = assert_packet_sent(EquipResult)
    assert query_bonuses(session.pid) == {3, 0}

    simulate_incoming_message(session.pid, %UnequipItem{
      index: PlayerState.client_index(inventory_index(session.pid, bow.id))
    })

    assert eventually(fn -> query_bonuses(session.pid) == {0, 0} end)
  end

  defp query_bonuses(pid) do
    equipment = get_player_state(pid).stats.modifiers.equipment
    {Map.get(equipment, :str, 0), Map.get(equipment, :hit, 0)}
  end

  defp request_equip(pid, row_id, position) do
    simulate_incoming_message(pid, %EquipItem{
      index: PlayerState.client_index(inventory_index(pid, row_id)),
      position: position
    })
  end

  defp inventory_index(pid, row_id) do
    Enum.find_value(get_player_state(pid).inventory, fn {index, item} ->
      if item.id == row_id, do: index
    end)
  end

  defp seed_item(character_id, item_id, equip, refine) do
    {:ok, item} =
      Persistence.insert_item(character_id, %{
        nameid: item_id,
        amount: 1,
        identify: 1,
        equip: equip,
        refine: refine
      })

    item
  end

  defp definition(id, type, attrs) do
    struct!(
      ItemDefinition,
      [id: id, aegis_name: "Query_#{id}", name: "Query #{id}", type: type, refineable: true] ++
        attrs
    )
  end

  defp insert_character do
    unique = System.unique_integer([:positive]) |> Integer.to_string(36)

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "eq#{unique}",
        user_pass: "password",
        sex: "M",
        email: "eq#{unique}@aesir.test"
      })
      |> Repo.insert()

    {:ok, job_id} = AvailableJobs.job_name_to_id(:rogue)

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Query#{unique}",
        class: job_id,
        sex: "M",
        base_level: 99,
        job_level: 1,
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        save_map: "prontera",
        save_x: 150,
        save_y: 150
      })
      |> Repo.insert()

    character
  end
end
