defmodule Aesir.ZoneServer.Unit.Pet.AccessoryHandlerTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.EquipResult
  alias Aesir.Net.ItemAddFailed
  alias Aesir.Net.PetEquipAccessoryCommand
  alias Aesir.Net.PetMenuCommand
  alias Aesir.Net.PetRequest
  alias Aesir.Net.PetResult
  alias Aesir.Net.PetStateChange
  alias Aesir.Net.SystemNotice
  alias Aesir.Net.UnitDespawn
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Pet.Handlers.AccessoryHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Pet.Runtime
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "pet_accessory_map"
  @backpack 10_013
  @apple_juice 531

  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 60, 60)})
    suffix = System.unique_integer([:positive])
    name = "pah#{suffix}"

    account =
      Repo.insert!(
        Account.changeset(%Account{}, %{
          username: name,
          userid: name,
          user_pass: "password",
          email: "#{name}@example.com"
        })
      )

    character =
      Repo.insert!(
        Character.changeset(%Character{}, %{
          account_id: account.id,
          char_num: 0,
          name: "Pah#{suffix}",
          class: 1,
          base_level: 1,
          str: 1,
          agi: 1,
          vit: 1,
          int: 1,
          dex: 1,
          luk: 1
        })
      )

    {:ok, definition} = Catalog.by_mob(1002)
    session = spawned(account, character, definition)
    observer = %{session.game_state | character_id: character.id + 1_000_000}
    UnitRegistry.register_player(observer, self())
    SpatialIndex.add_player(observer.character_id, session.pet.x, session.pet.y, @map)
    %{session: session}
  end

  test "the species' accessory is consumed, saved and shown to the area", %{session: session} do
    {session, index} = with_item(session, @backpack)

    equipped = AccessoryHandler.equip(session, index)

    assert equipped.pet.equip == @backpack
    refute Map.has_key?(equipped.game_state.inventory, index)
    assert Repo.get!(Pet, equipped.pet.pet_id).equip == @backpack
    assert_receive {:"$gen_cast", {:send_packet, %PetStateChange{type: :PET_STATE_ACCESSORY}}}
  end

  test "a wrong item, a second accessory or an empty slot fail; out of range is ignored",
       %{session: session} do
    {session, juice} = with_item(session, @apple_juice)
    {session, backpack} = with_item(session, @backpack)
    worn = put_in(session.pet.equip, @backpack)

    for {state, index} <- [
          {session, juice},
          {worn, backpack},
          {session, Inventory.capacity() - 1}
        ] do
      assert AccessoryHandler.equip(state, index) == state
      client_index = PlayerState.client_index(index)
      assert_receive {:send, _, {:equip_result, %EquipResult{index: ^client_index, result: 2}}}
    end

    assert AccessoryHandler.equip(session, -2) == session
    assert AccessoryHandler.equip(session, Inventory.capacity()) == session
    refute_received {:send, _, {:equip_result, _}}
  end

  test "unequip returns the accessory to the inventory", %{session: session} do
    session = worn(session)

    unequipped = AccessoryHandler.unequip(session)

    assert unequipped.pet.equip == 0
    assert Enum.any?(unequipped.game_state.inventory, fn {_, i} -> i.nameid == @backpack end)
    assert Repo.get!(Pet, session.pet.pet_id).equip == 0
    assert_receive {:"$gen_cast", {:send_packet, %PetStateChange{type: :PET_STATE_ACCESSORY}}}
  end

  test "a full inventory destroys the accessory only when pet_unequip_destroy is on",
       %{session: session} do
    session = session |> worn() |> full_inventory()

    stub(Config, :pet_unequip_destroy?, fn -> false end)
    assert AccessoryHandler.unequip(session) == session
    assert_receive {:send, _, {:item_add_failed, %ItemAddFailed{}}}
    assert Repo.get!(Pet, session.pet.pet_id).equip == @backpack

    stub(Config, :pet_unequip_destroy?, fn -> true end)
    destroyed = AccessoryHandler.unequip(session)
    assert destroyed.pet.equip == 0
    assert destroyed.game_state.inventory == session.game_state.inventory
    assert Repo.get!(Pet, session.pet.pet_id).equip == 0
    assert_receive {:"$gen_cast", {:send_packet, %PetStateChange{type: :PET_STATE_ACCESSORY}}}
  end

  test "a failed save rolls back and answers the requester with a failure",
       %{session: session} do
    {session, index} = with_item(session, @backpack)

    stub(Persistence, :save_with_inventory, fn _pet, _attrs, _id, _old, _new ->
      {:error, :down}
    end)

    assert {:noreply, ^session} = CommandHandler.request(equip_request(1, index), session)
    assert Repo.get!(Pet, session.pet.pet_id).equip == 0
    client_index = PlayerState.client_index(index)
    assert_receive {:send, _, {:equip_result, %EquipResult{index: ^client_index, result: 2}}}
    assert_receive {:send, _, {:pet_result, %PetResult{request_id: 1, success: false}}}

    worn = worn(session)

    unequip = %PetRequest{
      request_id: 2,
      command: {:menu, %PetMenuCommand{action: :PET_MENU_UNEQUIP}}
    }

    assert {:noreply, ^worn} = CommandHandler.request(unequip, worn)
    assert Repo.get!(Pet, session.pet.pet_id).equip == @backpack
    assert_receive {:send, _, {:pet_result, %PetResult{request_id: 2, success: false}}}
  end

  describe "the equip request gates" do
    test "a dead owner is refused and the dead state is resent to the area",
         %{session: session} do
      {session, index} = with_item(session, @backpack)
      owner = session.game_state
      observer = owner.character_id + 1_000_000
      dead = %{owner | action_state: :dead, visible_players: MapSet.new([observer])}
      session = %{session | game_state: dead}

      assert {:noreply, ^session} = CommandHandler.request(equip_request(1, index), session)
      assert_receive {:"$gen_cast", {:send_packet, %UnitDespawn{gid: gid, reason: reason}}}
      assert gid == owner.character_id and reason == DespawnReason.died()
      refute_received {:send, _, {:equip_result, _}}
    end

    test "an NPC dialog refusing items gets the can't-equip notice", %{session: session} do
      {session, index} = with_item(session, @backpack)
      lock = {self(), make_ref(), 0x5000_0001}
      session = %{session | interaction_lock: lock, npc_item_flag: false}

      assert {:noreply, ^session} = CommandHandler.request(equip_request(1, index), session)

      assert_receive {:send, _,
                      {:system_notice, %SystemNotice{id: :SYSTEM_NOTICE_ID_CAN_NOT_EQUIP_ITEM}}}

      refute_received {:send, _, {:equip_result, _}}
    end

    test "an unidentified accessory gets the equip failure", %{session: session} do
      {session, index} = with_item(session, @backpack)
      session = update_in(session.game_state.inventory[index], &%{&1 | identify: 0})

      assert {:noreply, ^session} = CommandHandler.request(equip_request(1, index), session)
      client_index = PlayerState.client_index(index)
      assert_receive {:send, _, {:equip_result, %EquipResult{index: ^client_index, result: 2}}}
    end

    test "a pet armor sent through the gear equip request equips the pet",
         %{session: session} do
      {session, index} = with_item(session, @backpack)

      assert {:noreply, equipped} = EquipmentHandler.handle_equip(index, 0, session)
      assert equipped.pet.equip == @backpack
      assert Repo.get!(Pet, session.pet.pet_id).equip == @backpack
    end
  end

  defp equip_request(request_id, index) do
    %PetRequest{
      request_id: request_id,
      command:
        {:equip_accessory, %PetEquipAccessoryCommand{index: PlayerState.client_index(index)}}
    }
  end

  defp worn(session) do
    Repo.update_all(from(p in Pet, where: p.id == ^session.pet.pet_id), set: [equip: @backpack])
    put_in(session.pet.equip, @backpack)
  end

  defp full_inventory(%SessionState{game_state: owner} = session) do
    filler =
      for i <- 0..(Inventory.capacity() - 1),
          into: %{},
          do: {i, %InventoryItem{id: -i, nameid: @apple_juice, amount: 1}}

    %{session | game_state: %{owner | inventory: Map.merge(filler, owner.inventory)}}
  end

  defp with_item(%SessionState{game_state: owner} = session, item_id) do
    {:ok, item} = ItemManagement.get_item_by_id(item_id)
    {:ok, inventory, {:added, index, _} = change} = Inventory.add(owner.inventory, item, 1)

    {:ok, inventory} =
      InventoryOps.persist_change(owner.character_id, owner.inventory, inventory, change)

    {%{session | game_state: %{owner | inventory: inventory}}, index}
  end

  defp spawned(account, character, definition) do
    {:ok, inventory, pet} =
      Persistence.create_with_egg(
        account.id,
        character.id,
        definition,
        %{level: 1, name: "Pet"},
        %{},
        :infinity
      )

    {:ok, inventory, _pet} = Persistence.hatch(pet, account.id, character.id, inventory)
    character = Repo.get!(Character, character.id)

    session = %SessionState{
      game_state: %PlayerState{
        character_id: character.id,
        account_id: character.account_id,
        character_name: character.name,
        map_name: @map,
        x: 10,
        y: 10,
        dir: 0,
        walk_speed: 150,
        movement_state: :standing,
        view_range: 14,
        inventory: inventory,
        stats: Stats.from_character(character)
      },
      connection_pid: self(),
      pet_runtime: %Runtime{generation: 3}
    }

    session |> LifecycleHandler.restore(character) |> LifecycleHandler.spawned_after_map_load()
  end
end
