defmodule Aesir.ZoneServer.Unit.Player.Handlers.StorageOpsTest do
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.StorageItem
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.StorageOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Storage.Persistence, as: StoragePersistence

  # Real item ids from priv/db/re/items (loaded into :persistent_term at boot).
  @potion 501
  @sword 1101
  @poring_card 4001

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(StoragePersistence)
    :ok
  end

  setup do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "testuser",
        userid: "testuser",
        user_pass: "password",
        email: "test@test.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "TestChar",
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

    %{account: account, character: character, stats: Stats.from_character(character)}
  end

  describe "deposit/6" do
    test "reduces the inventory row and inserts the storage row, both committed", %{
      account: account,
      character: char
    } do
      seed_inv(char.id, @potion, 10)
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)

      assert {:ok, p_inv, p_storage, {:reduced, ^index, 6}, {:added, 0, _}} =
               StorageOps.deposit(account.id, char.id, inventory, %{}, index, 4)

      assert %{^index => %InventoryItem{amount: 6}} = p_inv
      assert %{0 => %InventoryItem{nameid: @potion, amount: 4}} = p_storage

      assert [%InventoryItem{amount: 6}] = InventoryPersistence.load_inventory(char.id)

      assert [%StorageItem{nameid: @potion, amount: 4}] =
               StoragePersistence.load_storage(account.id)
    end

    test "removes the inventory row entirely when the whole stack moves", %{
      account: account,
      character: char
    } do
      seed_inv(char.id, @potion, 4)
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)

      assert {:ok, p_inv, _p_storage, {:removed, ^index}, {:added, 0, _}} =
               StorageOps.deposit(account.id, char.id, inventory, %{}, index, 4)

      assert p_inv == %{}
      assert [] = InventoryPersistence.load_inventory(char.id)
      assert [%StorageItem{amount: 4}] = StoragePersistence.load_storage(account.id)
    end

    test "stacks onto an existing plain storage stack", %{account: account, character: char} do
      seed_inv(char.id, @potion, 10, %{identify: 1})
      seed_storage(account.id, @potion, 5, %{identify: 1})
      inventory = inv_map(char.id)
      storage = storage_map(account.id)
      index = index_of(inventory, @potion)

      assert {:ok, _p_inv, _p_storage, {:reduced, ^index, 7}, {:stacked, _, 8}} =
               StorageOps.deposit(account.id, char.id, inventory, storage, index, 3)

      assert [%StorageItem{amount: 8}] = StoragePersistence.load_storage(account.id)
    end

    test "preserves refine/cards/unique_id/enchant_grade and does not merge a carded item with a plain stack",
         %{account: account, character: char} do
      seed_storage(account.id, @potion, 5)

      seed_inv(char.id, @potion, 1, %{
        refine: 7,
        card0: @poring_card,
        unique_id: 123_456,
        enchant_grade: 2
      })

      inventory = inv_map(char.id)
      storage = storage_map(account.id)
      index = index_of(inventory, @potion)

      assert {:ok, _p_inv, _p_storage, _inv_change, {:added, _, _}} =
               StorageOps.deposit(account.id, char.id, inventory, storage, index, 1)

      rows = StoragePersistence.load_storage(account.id)
      assert length(rows) == 2

      plain = Enum.find(rows, &(&1.card0 == 0))
      carded = Enum.find(rows, &(&1.card0 == @poring_card))

      assert plain.amount == 5
      assert carded.amount == 1
      assert carded.refine == 7
      assert carded.unique_id == 123_456
      assert carded.enchant_grade == 2
    end

    test "accepts non-rentals and rejects rentals without moving either item", %{
      account: account,
      character: char
    } do
      seed_inv(char.id, @potion, 1)
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)

      assert {:ok, %{}, %{0 => %InventoryItem{nameid: @potion, amount: 1}}, _, _} =
               StorageOps.deposit(account.id, char.id, inventory, %{}, index, 1)

      expire_time = ~N[2030-01-01 00:00:00]
      rental = seed_inv(char.id, @potion, 1, %{expire_time: expire_time})
      rental_inventory = inv_map(char.id)
      rental_index = index_of(rental_inventory, @potion)

      assert {:error, :not_storable} =
               StorageOps.deposit(
                 account.id,
                 char.id,
                 rental_inventory,
                 %{0 => rental},
                 rental_index,
                 1
               )

      assert [
               %InventoryItem{
                 id: rental_id,
                 nameid: @potion,
                 amount: 1,
                 expire_time: ^expire_time
               }
             ] =
               InventoryPersistence.load_inventory(char.id)

      assert rental_id == rental.id

      assert [%StorageItem{nameid: @potion, amount: 1}] =
               StoragePersistence.load_storage(account.id)
    end

    test "rejects an equipped item with :item_equipped and writes nothing", %{
      account: account,
      character: char
    } do
      seed_inv(char.id, @sword, 1, %{equip: 2})
      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)

      assert {:error, :item_equipped} =
               StorageOps.deposit(account.id, char.id, inventory, %{}, index, 1)

      assert [%InventoryItem{equip: 2}] = InventoryPersistence.load_inventory(char.id)
      assert [] = StoragePersistence.load_storage(account.id)
    end

    test "rejects a guild-bound item with :not_storable and writes nothing", %{
      account: account,
      character: char
    } do
      seed_inv(char.id, @potion, 1, %{bound: 2})
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)

      assert {:error, :not_storable} =
               StorageOps.deposit(account.id, char.id, inventory, %{}, index, 1)

      assert [%InventoryItem{amount: 1}] = InventoryPersistence.load_inventory(char.id)
      assert [] = StoragePersistence.load_storage(account.id)
    end

    test "rejects amount exceeding held with :insufficient_amount", %{
      account: account,
      character: char
    } do
      seed_inv(char.id, @potion, 2)
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)

      assert {:error, :insufficient_amount} =
               StorageOps.deposit(account.id, char.id, inventory, %{}, index, 5)

      assert [%InventoryItem{amount: 2}] = InventoryPersistence.load_inventory(char.id)
      assert [] = StoragePersistence.load_storage(account.id)
    end

    test "rejects deposit into a full storage with :storage_full and writes nothing", %{
      account: account,
      character: char
    } do
      seed_inv(char.id, @potion, 5)
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)

      full_storage =
        for i <- 0..599, into: %{}, do: {i, %InventoryItem{nameid: @sword, amount: 1}}

      assert {:error, :storage_full} =
               StorageOps.deposit(account.id, char.id, inventory, full_storage, index, 1)

      assert [%InventoryItem{amount: 5}] = InventoryPersistence.load_inventory(char.id)
      assert [] = StoragePersistence.load_storage(account.id)
    end
  end

  describe "withdraw/7" do
    test "reduces the storage row and adds the inventory row, both committed", %{
      account: account,
      character: char,
      stats: stats
    } do
      seed_storage(account.id, @potion, 10)
      storage = storage_map(account.id)
      index = index_of(storage, @potion)

      assert {:ok, p_inv, _p_storage, {:added, 0, _}, {:reduced, ^index, 6}} =
               StorageOps.withdraw(account.id, char.id, %{}, storage, stats, index, 4)

      assert %{0 => %InventoryItem{nameid: @potion, amount: 4}} = p_inv
      assert [%InventoryItem{amount: 4}] = InventoryPersistence.load_inventory(char.id)
      assert [%StorageItem{amount: 6}] = StoragePersistence.load_storage(account.id)
    end

    test "deletes the storage row when the whole stack moves back", %{
      account: account,
      character: char,
      stats: stats
    } do
      seed_storage(account.id, @potion, 4)
      storage = storage_map(account.id)
      index = index_of(storage, @potion)

      assert {:ok, _p_inv, p_storage, {:added, 0, _}, {:removed, ^index}} =
               StorageOps.withdraw(account.id, char.id, %{}, storage, stats, index, 4)

      assert p_storage == %{}
      assert [%InventoryItem{amount: 4}] = InventoryPersistence.load_inventory(char.id)
      assert [] = StoragePersistence.load_storage(account.id)
    end

    test "rejects when the player would be overweight and writes nothing", %{
      account: account,
      character: char,
      stats: stats
    } do
      max = Weight.max_weight(stats)
      fill = div(max, 70)

      seed_inv(char.id, @potion, fill)
      seed_storage(account.id, @potion, 1)
      inventory = inv_map(char.id)
      storage = storage_map(account.id)
      index = index_of(storage, @potion)

      assert {:error, :overweight} =
               StorageOps.withdraw(account.id, char.id, inventory, storage, stats, index, 1)

      assert [%InventoryItem{amount: ^fill}] = InventoryPersistence.load_inventory(char.id)
      assert [%StorageItem{amount: 1}] = StoragePersistence.load_storage(account.id)
    end
  end

  describe "atomicity across both tables" do
    test "a forced failure on the storage write rolls back the inventory write", %{
      account: account,
      character: char
    } do
      seed_inv(char.id, @potion, 10)
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)

      stub(StoragePersistence, :insert_item, fn _account_id, _attrs ->
        {:error, :forced_failure}
      end)

      assert {:error, :forced_failure} =
               StorageOps.deposit(account.id, char.id, inventory, %{}, index, 4)

      # The inventory reduce (10 -> 6) must have rolled back with the storage insert.
      assert [%InventoryItem{amount: 10}] = InventoryPersistence.load_inventory(char.id)
      assert [] = StoragePersistence.load_storage(account.id)
    end

    test "a forced failure on the storage update rolls back the inventory add", %{
      account: account,
      character: char,
      stats: stats
    } do
      seed_storage(account.id, @potion, 10, %{identify: 1})
      storage = storage_map(account.id)
      index = index_of(storage, @potion)

      stub(StoragePersistence, :update_item, fn _row, _attrs -> {:error, :forced_failure} end)

      assert {:error, :forced_failure} =
               StorageOps.withdraw(account.id, char.id, %{}, storage, stats, index, 4)

      # The inventory add must have rolled back with the storage reduce.
      assert [] = InventoryPersistence.load_inventory(char.id)
      assert [%StorageItem{amount: 10}] = StoragePersistence.load_storage(account.id)
    end
  end

  defp seed_inv(char_id, nameid, amount, attrs \\ %{}) do
    {:ok, item} =
      InventoryPersistence.insert_item(
        char_id,
        Map.merge(%{nameid: nameid, amount: amount}, attrs)
      )

    item
  end

  defp seed_storage(account_id, nameid, amount, attrs \\ %{}) do
    {:ok, item} =
      StoragePersistence.insert_item(
        account_id,
        Map.merge(%{nameid: nameid, amount: amount}, attrs)
      )

    item
  end

  defp inv_map(char_id) do
    items = InventoryPersistence.load_inventory(char_id)
    PlayerState.from_list(items)
  end

  defp storage_map(account_id) do
    account_id
    |> StoragePersistence.load_storage()
    |> Enum.map(&StoragePersistence.to_session_item/1)
    |> PlayerState.from_list()
  end

  defp index_of(map, nameid) do
    Enum.find_value(map, fn {index, item} ->
      if item.nameid == nameid, do: index
    end)
  end
end
