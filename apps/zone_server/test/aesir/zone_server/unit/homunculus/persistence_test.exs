defmodule Aesir.ZoneServer.Unit.Homunculus.PersistenceTest do
  use Aesir.DataCase, async: true
  use Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!
  setup :set_mimic_from_context

  setup do
    Mimic.copy(Repo)
    :ok
  end

  setup do
    suffix = System.unique_integer([:positive])
    username = "hp#{suffix}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: username,
        userid: username,
        user_pass: "password",
        email: "h#{suffix}@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "H#{suffix}",
        class: 1,
        base_level: 99,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      })
      |> Repo.insert()

    %{character: character}
  end

  test "loads the sole row for its character", %{character: character} do
    homunculus = insert_homunculus(character.id)

    assert %Homunculus{id: id, character_id: character_id} =
             Persistence.load_for_character(character.id)

    assert id == homunculus.id
    assert character_id == character.id
  end

  test "returns nil when the character has no Homunculus", %{character: character} do
    assert Persistence.load_for_character(character.id) == nil
  end

  test "creates a Homunculus and consumes its item in one commit", %{character: character} do
    old_inventory = inventory_with_item(character.id, 5)
    {:ok, new_inventory, change} = Inventory.remove(old_inventory, 0, 1)

    attrs =
      homunculus_attrs()
      |> Map.put(:character_id, character.id + 1)
      |> Map.put("character_id", character.id + 2)

    assert {:ok, persisted_inventory, %Homunculus{character_id: character_id}} =
             Persistence.create_with_item(
               character.id,
               attrs,
               old_inventory,
               {new_inventory, change}
             )

    assert character_id == character.id
    assert %{0 => %InventoryItem{amount: 4}} = persisted_inventory
    assert [%InventoryItem{amount: 4}] = InventoryPersistence.load_inventory(character.id)
  end

  test "updates a Homunculus and consumes an item without changing ownership", %{
    character: character
  } do
    homunculus = insert_homunculus(character.id)
    old_inventory = inventory_with_item(character.id, 5)
    {:ok, new_inventory, change} = Inventory.remove(old_inventory, 0, 2)

    assert {:ok, persisted_inventory, %Homunculus{name: "Renamed"}} =
             Persistence.transition_with_item(
               character.id,
               homunculus,
               %{"name" => "Renamed", "character_id" => character.id + 1},
               old_inventory,
               {new_inventory, change}
             )

    assert %{0 => %InventoryItem{amount: 3}} = persisted_inventory

    assert %Homunculus{name: "Renamed", character_id: character_id} =
             Persistence.load_for_character(character.id)

    assert character_id == character.id
  end

  test "semantic saves cannot change ownership", %{character: character} do
    homunculus = insert_homunculus(character.id)

    attrs =
      %{:lifecycle => "rested", :character_id => character.id + 1}
      |> Map.put("character_id", character.id + 2)

    assert {:ok, %Homunculus{lifecycle: "rested", character_id: character_id}} =
             Persistence.save_semantic(homunculus, attrs)

    assert character_id == character.id
    assert Persistence.load_for_character(character.id).character_id == character.id
  end

  test "checkpoints accept approved atom and string fields", %{character: character} do
    homunculus = insert_homunculus(character.id)

    assert {:ok, %Homunculus{hp: 70, sp: 40, active_remaining_ms: 1_000, cooldowns: cooldowns}} =
             Persistence.checkpoint(homunculus, %{
               "sp" => 40,
               "cooldowns" => %{"HLIF_HEAL" => 500},
               hp: 70,
               active_remaining_ms: 1_000
             })

    assert cooldowns == %{"HLIF_HEAL" => 500}
  end

  test "checkpoints reject unknown fields without changing the row", %{character: character} do
    homunculus = insert_homunculus(character.id)

    assert {:error, :invalid_checkpoint_fields} =
             Persistence.checkpoint(homunculus, %{"name" => "Ignored", hp: 70})

    assert %Homunculus{hp: 100, name: "Lif"} = Persistence.load_for_character(character.id)
  end

  test "checkpoints reject duplicate atom and string fields without changing the row", %{
    character: character
  } do
    homunculus = insert_homunculus(character.id)

    assert {:error, :invalid_checkpoint_fields} =
             Persistence.checkpoint(homunculus, %{"hp" => 60, hp: 70})

    assert %Homunculus{hp: 100} = Persistence.load_for_character(character.id)
  end

  test "deletes the Homunculus with an optional inventory change", %{character: character} do
    homunculus = insert_homunculus(character.id)
    old_inventory = inventory_with_item(character.id, 2)
    {:ok, new_inventory, change} = Inventory.remove(old_inventory, 0, 1)

    assert {:ok, %{0 => %InventoryItem{amount: 1}}, nil} =
             Persistence.delete(homunculus, {old_inventory, {new_inventory, change}})

    assert Persistence.load_for_character(character.id) == nil
  end

  test "create failure rolls back inventory and returns no advanced state", %{
    character: character
  } do
    old_inventory = inventory_with_item(character.id, 5)
    {:ok, new_inventory, change} = Inventory.remove(old_inventory, 0, 1)
    inject_repo_failure(:insert)

    assert {:error, {:homunculus, %Ecto.Changeset{}}} =
             Persistence.create_with_item(
               character.id,
               homunculus_attrs(),
               old_inventory,
               {new_inventory, change}
             )

    assert [%InventoryItem{amount: 5}] = InventoryPersistence.load_inventory(character.id)
    assert Persistence.load_for_character(character.id) == nil
    assert %{0 => %InventoryItem{amount: 5}} = old_inventory
  end

  test "update failure rolls back inventory and preserves the original Homunculus", %{
    character: character
  } do
    homunculus = insert_homunculus(character.id)
    old_inventory = inventory_with_item(character.id, 5)
    {:ok, new_inventory, change} = Inventory.remove(old_inventory, 0, 1)
    inject_repo_failure(:update)

    assert {:error, {:homunculus, %Ecto.Changeset{}}} =
             Persistence.transition_with_item(
               character.id,
               homunculus,
               %{name: "Not Persisted"},
               old_inventory,
               {new_inventory, change}
             )

    assert [%InventoryItem{amount: 5}] = InventoryPersistence.load_inventory(character.id)
    assert %Homunculus{name: "Lif"} = Persistence.load_for_character(character.id)
    assert homunculus.name == "Lif"
  end

  test "delete failure rolls back inventory and preserves the returned state", %{
    character: character
  } do
    homunculus = insert_homunculus(character.id)
    old_inventory = inventory_with_item(character.id, 5)
    {:ok, new_inventory, change} = Inventory.remove(old_inventory, 0, 1)
    inject_repo_failure(:delete)

    assert {:error, {:homunculus, %Ecto.Changeset{}}} =
             Persistence.delete(homunculus, {old_inventory, {new_inventory, change}})

    assert [%InventoryItem{amount: 5}] = InventoryPersistence.load_inventory(character.id)
    assert %Homunculus{id: id, name: "Lif"} = Persistence.load_for_character(character.id)
    assert id == homunculus.id
  end

  defp inject_repo_failure(operation) do
    stub(Repo, operation, fn
      %Ecto.Changeset{data: %Homunculus{}} = changeset, _opts ->
        {:error, Ecto.Changeset.add_error(changeset, :base, "injected failure")}

      changeset, opts ->
        Mimic.call_original(Repo, operation, [changeset, opts])
    end)
  end

  defp inventory_with_item(character_id, amount) do
    {:ok, item} =
      InventoryPersistence.insert_item(character_id, %{
        nameid: 7142,
        amount: amount,
        identify: 1
      })

    PlayerState.from_list([item])
  end

  defp homunculus_attrs(attrs \\ %{}) do
    Map.merge(
      %{
        class_id: 6_001,
        name: "Lif",
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50
      },
      attrs
    )
  end

  defp insert_homunculus(character_id, attrs \\ %{}) do
    defaults = Map.put(homunculus_attrs(), :character_id, character_id)

    {:ok, homunculus} =
      %Homunculus{}
      |> Homunculus.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    homunculus
  end
end
