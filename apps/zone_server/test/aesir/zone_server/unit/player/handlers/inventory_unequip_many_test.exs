defmodule Aesir.ZoneServer.Unit.Player.Handlers.InventoryUnequipManyTest do
  use Aesir.DataCase, async: true
  use Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps

  @right_hand 2
  @left_hand 32

  setup :verify_on_exit!

  setup do
    Mimic.set_mimic_private()
    Mimic.copy(Persistence)

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "unequip_many",
        userid: "unequip_many",
        user_pass: "password",
        email: "unequip_many@test.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "UnequipMany",
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

  test "unequips multiple rows atomically and returns persisted rows", %{character: character} do
    first = seed_item(character.id, 1101, %{amount: 2, equip: @right_hand, refine: 4})
    second = seed_item(character.id, 2101, %{amount: 3, equip: @left_hand, favorite: 1})
    inventory = %{3 => first, 8 => second}

    assert {:ok, persisted} = InventoryOps.unequip_many(character.id, inventory, [3, 8])

    assert persisted[3].equip == 0
    assert persisted[8].equip == 0
    assert persisted[3].amount == 2
    assert persisted[8].amount == 3
    assert persisted[3].refine == 4
    assert persisted[8].favorite == 1
    assert persisted[3] == Repo.get!(InventoryItem, first.id)
    assert persisted[8] == Repo.get!(InventoryItem, second.id)
    assert map_size(persisted) == 2
  end

  test "rolls back an earlier update when a later row fails and leaves caller memory unchanged",
       %{
         character: character
       } do
    first = seed_item(character.id, 1101, %{equip: @right_hand})
    second = seed_item(character.id, 2101, %{equip: @left_hand})
    inventory = %{3 => first, 8 => second}
    second_id = second.id

    stub(Persistence, :update_item, fn
      %InventoryItem{id: ^second_id}, %{equip: 0} ->
        {:error, :later_row_failed}

      item, attrs ->
        Mimic.call_original(Persistence, :update_item, [item, attrs])
    end)

    assert {:error, :later_row_failed} =
             InventoryOps.unequip_many(character.id, inventory, [3, 8])

    assert inventory == %{3 => first, 8 => second}
    assert Repo.get!(InventoryItem, first.id).equip == @right_hand
    assert Repo.get!(InventoryItem, second.id).equip == @left_hand
  end

  test "propagates core errors and rolls back earlier writes", %{character: character} do
    for {later_index, later_item, expected_error} <- [
          {8, seed_item(character.id, 2101, %{equip: 0}), :not_equipped},
          {99, nil, :not_found}
        ] do
      first = seed_item(character.id, 1101, %{equip: @right_hand})
      inventory = %{3 => first}
      inventory = if later_item, do: Map.put(inventory, later_index, later_item), else: inventory

      assert {:error, ^expected_error} =
               InventoryOps.unequip_many(character.id, inventory, [3, later_index])

      assert Repo.get!(InventoryItem, first.id).equip == @right_hand
    end
  end

  test "returns the original inventory for an empty list without a transaction", %{
    character: character
  } do
    item = seed_item(character.id, 1101, %{equip: @right_hand})
    inventory = %{3 => item}
    test_pid = self()

    stub(Persistence, :transaction, fn _fun ->
      send(test_pid, :transaction_started)
      {:error, :unexpected_transaction}
    end)

    assert {:ok, ^inventory} = InventoryOps.unequip_many(character.id, inventory, [])
    refute_received :transaction_started
    assert Repo.get!(InventoryItem, item.id).equip == @right_hand
  end

  defp seed_item(char_id, nameid, attrs) do
    {:ok, item} =
      Persistence.insert_item(
        char_id,
        Map.merge(%{nameid: nameid, amount: 1, identify: 1}, attrs)
      )

    item
  end
end
