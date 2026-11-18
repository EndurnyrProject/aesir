defmodule Aesir.ZoneServer.Integration.PetRelationshipIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  import Bitwise

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.PetEggList
  alias Aesir.Net.PetEquipAccessoryCommand
  alias Aesir.Net.PetFoodResult
  alias Aesir.Net.PetMenuCommand
  alias Aesir.Net.PetRenameCommand
  alias Aesir.Net.PetRequest
  alias Aesir.Net.PetResult
  alias Aesir.Net.PetSelectEggCommand
  alias Aesir.Net.PetSetAutofeedCommand
  alias Aesir.Net.PetStateChange
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @map "pet_relationship_e2e"
  @warp_map "pet_relationship_warp_e2e"
  @poring 1_002
  @incubator 643

  setup {Aesir.MimicMode, :global}

  setup do
    put_map(@map)
    put_map(@warp_map)
    start_per_test_map(@map)
    start_per_test_map(@warp_map)
    :ok
  end

  test "feeding raises intimacy, overfeeding makes the pet run away and a warp deletes it" do
    {:ok, poring} = Catalog.by_mob(@poring)
    character = character_fixture("PetFeed")
    seed_item(character.id, @incubator)
    seed_item(character.id, poring.food_item_id, 3)
    owner = start(character, @map, {50, 50})
    pet_id = hatch(owner.pid, poring, hungry: 80, intimate: 150)

    feed(owner.pid, 1)
    assert_receive {:packet_sent, %PetFoodResult{success: true}, _}, 1_000
    assert %PetState{intimate: 175, hungry: 100} = PlayerSession.get_state(owner.pid).pet

    feed(owner.pid, 2)
    assert_receive {:packet_sent, %PetFoodResult{success: true}, _}, 1_000
    assert %PetState{intimate: 75} = PlayerSession.get_state(owner.pid).pet

    feed(owner.pid, 3)
    assert_receive {:packet_sent, %PetStateChange{type: :PET_STATE_INTIMACY, value: 0}, _}, 1_000
    ran_away = PlayerSession.get_state(owner.pid).pet
    assert %PetState{intimate: 0} = ran_away
    assert held_item(owner.pid, poring.egg_item_id) == nil
    assert %Pet{intimate: 0} = Repo.get!(Pet, pet_id)

    assert_eventually(fn ->
      %PetState{x: x, y: y} = PlayerSession.get_state(owner.pid).pet
      {x, y} != {ran_away.x, ran_away.y}
    end)

    PlayerSession.warp(owner.pid, @warp_map, 40, 40)
    simulate_incoming_message(owner.pid, %MapLoaded{})

    assert_eventually(fn ->
      PlayerSession.get_state(owner.pid).game_state.map_name == @warp_map
    end)

    assert PlayerSession.get_state(owner.pid).pet == nil
    assert Repo.get(Pet, pet_id) == nil
    assert Repo.get!(Character, character.id).pet_id == 0
    assert UnitRegistry.count_units_by_type(:pet) == 0
  end

  test "a bonded pet boosts the owner, takes one rename and wears its accessory" do
    {:ok, poring} = Catalog.by_mob(@poring)
    character = character_fixture("PetCord")
    seed_item(character.id, @incubator)
    seed_item(character.id, poring.equip_item_id)
    owner = start(character, @map, {50, 50})
    base = PlayerSession.get_state(owner.pid).game_state.stats

    # The Poring's first bonus tier (LUK +2, CRIT +1) is Cordial in renewal and
    # Loyal in pre-renewal.
    intimate = if GameMode.mode() == :renewal, do: 800, else: 910
    pet_id = hatch(owner.pid, poring, intimate: intimate)

    bonded = PlayerSession.get_state(owner.pid).game_state.stats
    assert Stats.get_effective_stat(bonded, :luk) == Stats.get_effective_stat(base, :luk) + 2
    assert Stats.get_equipment_modifier(bonded, :critical) == 1

    request(owner.pid, 10, {:rename, %PetRenameCommand{name: "Bubbles"}})
    assert_receive {:packet_sent, %PetResult{request_id: 10, success: true}, _}, 1_000
    assert %PetState{name: "Bubbles", rename_flag: 1} = PlayerSession.get_state(owner.pid).pet
    assert %Pet{name: "Bubbles", rename_flag: 1} = Repo.get!(Pet, pet_id)
    assert (held_item(owner.pid, poring.egg_item_id).card3 &&& 1) == 1

    request(owner.pid, 11, {:rename, %PetRenameCommand{name: "Again"}})
    assert_receive {:packet_sent, %PetResult{request_id: 11, success: false}, _}, 1_000
    assert %PetState{name: "Bubbles"} = PlayerSession.get_state(owner.pid).pet

    accessory_index = client_index(owner.pid, poring.equip_item_id)
    request(owner.pid, 12, {:equip_accessory, %PetEquipAccessoryCommand{index: accessory_index}})
    assert_receive {:packet_sent, %PetResult{request_id: 12, success: true}, _}, 1_000
    assert_receive {:packet_sent, %PetStateChange{type: :PET_STATE_ACCESSORY}, _}, 1_000
    assert %PetState{equip: equip} = PlayerSession.get_state(owner.pid).pet
    assert equip == poring.equip_item_id
    assert held_item(owner.pid, poring.equip_item_id) == nil
    assert Repo.get!(Pet, pet_id).equip == poring.equip_item_id

    request(owner.pid, 13, {:menu, %PetMenuCommand{action: :PET_MENU_UNEQUIP}})
    assert_receive {:packet_sent, %PetResult{request_id: 13, success: true}, _}, 1_000
    assert %PetState{equip: 0} = PlayerSession.get_state(owner.pid).pet
    assert held_item(owner.pid, poring.equip_item_id) != nil
    assert Repo.get!(Pet, pet_id).equip == 0
  end

  # Pre-renewal pet_db has no species that allows autofeed.
  @tag game_mode: :renewal, integration_pre_re: false
  test "autofeed feeds a hungry pet on the hunger tick once enabled" do
    # A 1% hunger delay rate brings the 120 s tick down to 1.2 s.
    stub(Config, :pet_hungry_delay_rate, fn -> 1 end)

    {:ok, metaller} = Catalog.by_mob(1_058)
    assert metaller.allow_auto_feed
    character = character_fixture("PetAuto")
    seed_item(character.id, @incubator)
    seed_item(character.id, metaller.food_item_id)
    owner = start(character, @map, {50, 50})
    pet_id = hatch(owner.pid, metaller, hungry: 90)

    request(owner.pid, 20, {:set_autofeed, %PetSetAutofeedCommand{enabled: true}})
    assert_receive {:packet_sent, %PetResult{request_id: 20, success: true}, _}, 1_000

    food = metaller.food_item_id
    assert_receive {:packet_sent, %PetFoodResult{success: true, food_item_id: ^food}, _}, 3_000
    assert held_item(owner.pid, food) == nil
    assert %PetState{hungry: 100, autofeed: true} = PlayerSession.get_state(owner.pid).pet
    assert %Pet{hungry: 100, autofeed: true} = Repo.get!(Pet, pet_id)
  end

  # Grants the species' egg, sets the pet row's fields while it is still in
  # the egg, then hatches it through the incubator.
  defp hatch(pid, definition, row_attrs) do
    pid |> npc_ctx() |> Dsl.give_item(definition.egg_item_id, 1)
    pet_id = pid |> held_item(definition.egg_item_id) |> Egg.pet_id()
    Pet |> Repo.get!(pet_id) |> Ecto.Changeset.change(row_attrs) |> Repo.update!()

    flush_packets()
    simulate_incoming_message(pid, %UseItem{index: client_index(pid, @incubator)})
    assert_receive {:packet_sent, %PetEggList{indexes: [egg_index]}, _}, 1_000
    request(pid, 1, {:select_egg, %PetSelectEggCommand{index: egg_index}})
    assert_receive {:packet_sent, %PetResult{request_id: 1, success: true}, _}, 1_000
    assert %PetState{pet_id: ^pet_id} = PlayerSession.get_state(pid).pet
    flush_packets()
    pet_id
  end

  defp feed(pid, request_id) do
    request(pid, request_id, {:menu, %PetMenuCommand{action: :PET_MENU_FEED}})
    assert_receive {:packet_sent, %PetResult{request_id: ^request_id, success: true}, _}, 1_000
  end

  defp start(character, map_name, position) do
    session = start_player_session(character: character, map_name: map_name, position: position)
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    flush_packets()
    session
  end

  defp request(pid, request_id, command) do
    simulate_incoming_message(pid, %PetRequest{request_id: request_id, command: command})
  end

  defp npc_ctx(pid) do
    session = PlayerSession.get_state(pid)

    %Ctx{
      char_id: session.game_state.character_id,
      account_id: session.game_state.account_id,
      connection_pid: session.connection_pid,
      game_state: session.game_state,
      source: {:npc, :pet_relationship_e2e},
      session_pid: pid
    }
  end

  defp held_item(pid, nameid) do
    PlayerSession.get_state(pid).game_state.inventory
    |> Map.values()
    |> Enum.find(&(&1.nameid == nameid))
  end

  defp client_index(pid, nameid) do
    {index, _item} =
      Enum.find(PlayerSession.get_state(pid).game_state.inventory, fn {_index, item} ->
        item.nameid == nameid
      end)

    index + 2
  end

  defp character_fixture(prefix) do
    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "petrel#{suffix}",
        user_pass: "password",
        email: "petrel#{suffix}@example.com"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "#{prefix}#{suffix}",
      class: 0,
      base_level: 10,
      job_level: 10,
      learned_skills: %{"1" => 9},
      last_map: @map,
      last_x: 50,
      last_y: 50
    })
    |> Repo.insert!()
  end

  defp seed_item(character_id, nameid, amount \\ 1) do
    {:ok, _} =
      InventoryPersistence.insert_item(character_id, %{
        nameid: nameid,
        amount: amount,
        identify: 1
      })
  end

  defp put_map(name) do
    :ets.insert(EtsTable.table_for(:map_cache), {name, MapData.new(name, 100, 100)})
  end
end
