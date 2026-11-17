defmodule Aesir.ZoneServer.Unit.Pet.PersistenceTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.Pet
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup do
    suffix = System.unique_integer([:positive])
    username = "pet#{suffix}"

    account =
      Repo.insert!(
        Account.changeset(%Account{}, %{
          username: username,
          userid: username,
          user_pass: "password",
          email: "#{username}@example.com"
        })
      )

    character =
      Repo.insert!(
        Character.changeset(%Character{}, %{
          account_id: account.id,
          char_num: 0,
          name: "Pet#{suffix}",
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
    %{account: account, character: character, definition: definition}
  end

  test "expiring a catalog egg deletes the pet encoded in its card words", %{
    account: account,
    character: character,
    definition: definition
  } do
    setup_ets_tables(%{})

    {:ok, _, pet} =
      Persistence.create_with_egg(
        account.id,
        character.id,
        definition,
        %{level: 1, name: "Poring"},
        %{},
        :infinity
      )

    item = %{
      GroundItem.new(definition.egg_item_id, 1, 1, 1, true, cards: [0, pet.id, 0, 0])
      | dropped_at: System.monotonic_time(:millisecond) - 1_000_000
    }

    GroundItemStore.put("prontera", item)

    short_cards = %{
      GroundItem.new(501, 1, 1, 1, true, cards: [])
      | dropped_at: System.monotonic_time(:millisecond) - 1_000_000
    }

    GroundItemStore.put("prontera", short_cards)

    assert {:noreply, _} =
             Coordinator.handle_info(:expire_ground_items, %Coordinator{map_name: "prontera"})

    refute Repo.get(Pet, pet.id)
  end

  test "script deletion removes the selected egg's pet but not an unmarked egg's pet", %{
    account: account,
    character: character,
    definition: definition
  } do
    {:ok, inventory, pet} =
      Persistence.create_with_egg(
        account.id,
        character.id,
        definition,
        %{level: 1, name: "Poring"},
        %{},
        :infinity
      )

    {:ok, plain} =
      InventoryPersistence.insert_item(character.id, %{nameid: definition.egg_item_id, amount: 2})

    inventory = Map.put(inventory, 1, plain)

    state = %{
      game_state: %PlayerState{character_id: character.id, inventory: inventory},
      connection_pid: self()
    }

    assert Repo.get(Pet, pet.id)

    assert {{:ok, _}, updated} =
             ScriptEffectHandler.apply_op({:delitem, definition.egg_item_id, 1}, state)

    refute Repo.get(Pet, pet.id)
    assert updated.game_state.inventory[1].amount == 2

    {:ok, inventory, other} =
      Persistence.create_with_egg(
        account.id,
        character.id,
        definition,
        %{level: 1, name: "Poring"},
        %{},
        :infinity
      )

    [{index, egg}] = Map.to_list(inventory)
    {:ok, egg} = Repo.update(Ecto.Changeset.change(egg, card0: 0))
    state = %{state | game_state: %{state.game_state | inventory: %{index => egg}}}

    assert {{:ok, _}, _} =
             ScriptEffectHandler.apply_op({:delitem, definition.egg_item_id, 1}, state)

    assert Repo.get(Pet, other.id)
  end

  test "creation, hatching and returning persist the pet and egg atomically", %{
    account: account,
    character: character,
    definition: definition
  } do
    assert {:ok, inventory, pet} =
             Persistence.create_with_egg(
               account.id,
               character.id,
               definition,
               %{level: 1, name: "Poring"},
               %{},
               :infinity
             )

    assert pet.incubate == 1
    assert {pet.account_id, pet.char_id} == {0, 0}
    assert {:ok, egg} = Egg.find(inventory, pet.id)
    assert egg.attribute == 0
    assert {:ok, inventory, pet} = Persistence.hatch(pet, account.id, character.id, inventory)
    assert pet.incubate == 0
    assert {pet.account_id, pet.char_id} == {account.id, character.id}
    assert Repo.get!(InventoryItem, egg.id).attribute == 1
    assert {:ok, %{attribute: 1}} = Egg.find(inventory, pet.id)
    assert Repo.get!(Character, character.id).pet_id == pet.id
    assert {:ok, inventory, pet} = Persistence.return_to_egg(pet, character.id, inventory)
    assert pet.incubate == 1
    assert {:ok, %{attribute: 0}} = Egg.find(inventory, pet.id)
    assert Repo.get!(InventoryItem, egg.id).attribute == 0
    assert Repo.get!(Character, character.id).pet_id == 0
  end

  test "overweight egg grant rolls back the pet row", %{
    account: account,
    character: character,
    definition: definition
  } do
    assert {:error, :overweight} =
             Persistence.create_with_egg(
               account.id,
               character.id,
               definition,
               %{level: 1, name: "Poring"},
               %{},
               -1
             )

    assert Repo.all(Pet) == []
  end

  test "full inventory rolls back the pet row", %{
    account: account,
    character: character,
    definition: definition
  } do
    full = Map.new(0..99, fn index -> {index, %InventoryItem{nameid: 501, amount: 1}} end)

    assert {:error, :inventory_full} =
             Persistence.create_with_egg(
               account.id,
               character.id,
               definition,
               %{level: 1, name: "Poring"},
               full,
               :infinity
             )

    assert Repo.all(Pet) == []
  end

  test "hatching without an egg changes nothing", %{
    account: account,
    character: character,
    definition: definition
  } do
    {:ok, inventory, pet} =
      Persistence.create_with_egg(
        account.id,
        character.id,
        definition,
        %{level: 1, name: "Poring"},
        %{},
        :infinity
      )

    assert {:error, :egg_missing} = Persistence.hatch(pet, account.id, character.id, %{})
    assert Persistence.load(pet.id).incubate == 1
    assert Repo.get!(Character, character.id).pet_id == 0
    assert {:ok, %{attribute: 0}} = Egg.find(inventory, pet.id)
  end

  test "delete clears only a matching character reference", %{
    account: account,
    character: character,
    definition: definition
  } do
    {:ok, _, first} =
      Persistence.create_with_egg(
        account.id,
        character.id,
        definition,
        %{level: 1, name: "Poring"},
        %{},
        :infinity
      )

    {:ok, _, second} =
      Persistence.create_with_egg(
        account.id,
        character.id,
        definition,
        %{level: 1, name: "Poring"},
        %{},
        :infinity
      )

    Repo.update_all(from(c in Character, where: c.id == ^character.id), set: [pet_id: second.id])
    assert :ok = Persistence.delete(first.id, character.id)
    assert Repo.get!(Character, character.id).pet_id == second.id
    assert :ok = Persistence.delete(second.id, character.id)
    assert Repo.get!(Character, character.id).pet_id == 0
  end

  test "inventory updates and pet changes roll back together", %{
    account: account,
    character: character,
    definition: definition
  } do
    {:ok, inventory, pet} =
      Persistence.create_with_egg(
        account.id,
        character.id,
        definition,
        %{level: 1, name: "Poring"},
        %{},
        :infinity
      )

    assert {:error, _} =
             Persistence.save_with_inventory(pet, %{hungry: 101}, character.id, inventory, %{})

    assert {:ok, egg} = Egg.find(inventory, pet.id)
    assert Repo.get!(InventoryItem, egg.id)
    assert Persistence.load(pet.id).hungry == 100

    assert {:ok, %{}, updated} =
             Persistence.save_with_inventory(pet, %{hungry: 50}, character.id, inventory, %{})

    assert updated.hungry == 50
    refute Repo.get(InventoryItem, egg.id)
  end

  test "inventory replacement persists the new row", %{
    account: account,
    character: character,
    definition: definition
  } do
    {:ok, inventory, pet} =
      Persistence.create_with_egg(
        account.id,
        character.id,
        definition,
        %{level: 1, name: "Poring"},
        %{},
        :infinity
      )

    [{index, old}] = Map.to_list(inventory)
    replacement = %InventoryItem{nameid: 501, amount: 1}

    assert {:ok, updated, _pet} =
             Persistence.save_with_inventory(pet, %{hungry: 90}, character.id, inventory, %{
               index => replacement
             })

    assert %{^index => %InventoryItem{nameid: 501, id: id}} = updated
    assert Repo.get!(InventoryItem, id).nameid == 501
    refute Repo.get(InventoryItem, old.id)
  end
end
