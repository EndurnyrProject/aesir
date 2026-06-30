defmodule Aesir.ZoneServer.Unit.Player.Handlers.InventoryOpsTest do
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  # Real equip.yml ids.
  @sword 1101
  @guard 2101
  @potion 501

  @right_hand 2
  @left_hand 32

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(Persistence)
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

  defp seed_item(char_id, nameid, amount, attrs \\ %{}) do
    {:ok, item} =
      Persistence.insert_item(char_id, Map.merge(%{nameid: nameid, amount: amount}, attrs))

    item
  end

  defp def!(id) do
    {:ok, d} = ItemManagement.get_item_by_id(id)
    d
  end

  defp load(char_id) do
    items = Persistence.load_inventory(char_id)
    PlayerState.from_list(items)
  end

  describe "apply_change/4 — added" do
    test "inserts the new row and reflects its real DB id into the map", %{character: char} do
      def_ = def!(@sword)
      {:ok, new_inv, {:added, 0, _} = change} = Inventory.add(%{}, def_, 1)

      assert {:ok, persisted} = InventoryOps.apply_change(char.id, %{}, new_inv, change)

      assert %{0 => %InventoryItem{id: id, nameid: @sword}} = persisted
      assert is_integer(id)

      assert [%InventoryItem{nameid: @sword}] = Persistence.load_inventory(char.id)
    end
  end

  describe "add/6 — weight enforced, persisted" do
    test "persists the item and returns the change", %{character: char, stats: stats} do
      def_ = def!(@potion)
      inv = %{}

      assert {:ok, persisted, {:added, 0, _}} = InventoryOps.add(char.id, inv, stats, def_, 5)
      assert %{0 => %InventoryItem{nameid: @potion, amount: 5}} = persisted

      assert [%InventoryItem{nameid: @potion, amount: 5}] =
               Persistence.load_inventory(char.id)
    end

    test "rejects an add past max weight with no DB write", %{character: char, stats: stats} do
      # Sword weighs 500; clamp str so max weight is tiny relative to the add.
      tiny = put_in(stats.base_stats.str, 1)
      def_ = def!(@sword)

      # A single sword is fine, but a huge stack exceeds max weight.
      huge_amount = div(Weight.max_weight(tiny), def_.weight) + 100

      assert {:error, :overweight} = InventoryOps.add(char.id, %{}, tiny, def_, huge_amount)
      assert [] = Persistence.load_inventory(char.id)
    end
  end

  describe "apply_change/4 — stacked and split" do
    test "stacked updates the existing row amount", %{character: char} do
      seed_item(char.id, @potion, 5)
      inv = load(char.id)
      def_ = def!(@potion)

      {:ok, new_inv, {:stacked, 0, 8} = change} = Inventory.add(inv, def_, 3)

      assert {:ok, persisted} = InventoryOps.apply_change(char.id, inv, new_inv, change)
      assert %{0 => %InventoryItem{amount: 8}} = persisted
      assert [%InventoryItem{amount: 8}] = Persistence.load_inventory(char.id)
    end

    test "split tops the existing row and inserts the remainder, both persisted", %{
      character: char
    } do
      seed_item(char.id, @potion, 29_999)
      inv = load(char.id)
      def_ = def!(@potion)

      {:ok, new_inv, {:split, [{0, 30_000}, {1, 4}]} = change} = Inventory.add(inv, def_, 5)

      assert {:ok, persisted} = InventoryOps.apply_change(char.id, inv, new_inv, change)
      assert %{0 => %InventoryItem{amount: 30_000}, 1 => %InventoryItem{amount: 4}} = persisted
      assert %{1 => %InventoryItem{id: id}} = persisted
      assert is_integer(id)

      rows = Persistence.load_inventory(char.id)
      assert Enum.map(rows, & &1.amount) |> Enum.sort() == [4, 30_000]
    end
  end

  describe "remove/4" do
    test "reduces the amount and persists", %{character: char} do
      seed_item(char.id, @potion, 10)
      inv = load(char.id)

      assert {:ok, persisted, {:reduced, 0, 7}} = InventoryOps.remove(char.id, inv, 0, 3)
      assert %{0 => %InventoryItem{amount: 7}} = persisted
      assert [%InventoryItem{amount: 7}] = Persistence.load_inventory(char.id)
    end

    test "deletes the row when the amount reaches zero", %{character: char} do
      seed_item(char.id, @potion, 3)
      inv = load(char.id)

      assert {:ok, persisted, {:removed, 0}} = InventoryOps.remove(char.id, inv, 0, 3)
      assert persisted == %{}
      assert [] = Persistence.load_inventory(char.id)
    end
  end

  describe "apply_change/4 — equipped with conflict" do
    test "equipping a two-hander unequips the worn shield in one transaction", %{character: char} do
      _shield = seed_item(char.id, @guard, 1, %{equip: @left_hand})
      _katana_row = seed_item(char.id, 1116, 1)
      inv = load(char.id)

      katana_index = index_of(inv, 1116)
      shield_index = index_of(inv, @guard)

      {:ok, new_inv, {:equipped, ^katana_index, 34, unequipped} = change} =
        Inventory.equip(inv, katana_index, 34, %{job_id: 1, base_level: 99})

      assert shield_index in unequipped

      assert {:ok, persisted} = InventoryOps.apply_change(char.id, inv, new_inv, change)

      assert %{^katana_index => %InventoryItem{equip: 34}} = persisted
      assert %{^shield_index => %InventoryItem{equip: 0}} = persisted

      reloaded = load(char.id)
      assert reloaded[katana_index].equip == 34
      assert reloaded[shield_index].equip == 0
    end
  end

  describe "apply_change/4 — unequipped" do
    test "clears the equip mask and persists", %{character: char} do
      _sword = seed_item(char.id, @sword, 1, %{equip: @right_hand})
      inv = load(char.id)
      idx = index_of(inv, @sword)

      {:ok, new_inv, {:unequipped, ^idx} = change} = Inventory.unequip(inv, idx)

      assert {:ok, persisted} = InventoryOps.apply_change(char.id, inv, new_inv, change)
      assert %{^idx => %InventoryItem{equip: 0}} = persisted
      assert load(char.id)[idx].equip == 0
    end
  end

  describe "persist-first on failure" do
    test "rolls back and reports the error without committing", %{character: char} do
      _sword = seed_item(char.id, @sword, 1, %{equip: @right_hand})
      inv = load(char.id)
      idx = index_of(inv, @sword)

      {:ok, new_inv, change} = Inventory.unequip(inv, idx)

      stub(Persistence, :transaction, fn _fun -> {:error, :persist_failed} end)

      assert {:error, :persist_failed} = InventoryOps.apply_change(char.id, inv, new_inv, change)

      # DB unchanged: the sword stays equipped.
      assert load(char.id)[idx].equip == @right_hand
    end

    test "mid-transaction failure on shield unequip rolls back the weapon equip write", %{
      character: char
    } do
      _shield = seed_item(char.id, @guard, 1, %{equip: @left_hand})
      _katana = seed_item(char.id, 1116, 1)
      inv = load(char.id)

      katana_index = index_of(inv, 1116)
      shield_index = index_of(inv, @guard)

      {:ok, new_inv, {:equipped, ^katana_index, 34, unequipped} = change} =
        Inventory.equip(inv, katana_index, 34, %{job_id: 1, base_level: 99})

      assert shield_index in unequipped

      # Let the weapon-equip write (equip → non-zero) go through the real Repo,
      # but make the shield-unequip write (equip → 0) fail so the transaction
      # rolls back and we verify atomicity.
      stub(Persistence, :update_item, fn
        item, %{equip: 0} ->
          fake_cs = InventoryItem.changeset(item, %{})
          {:error, fake_cs}

        item, attrs ->
          Mimic.call_original(Persistence, :update_item, [item, attrs])
      end)

      assert {:error, _} = InventoryOps.apply_change(char.id, inv, new_inv, change)

      # Both rows must be unchanged after rollback.
      reloaded = load(char.id)
      assert reloaded[katana_index].equip == 0
      assert reloaded[shield_index].equip == @left_hand
    end
  end

  defp index_of(inventory, nameid) do
    Enum.find_value(inventory, fn {index, item} ->
      if item.nameid == nameid, do: index
    end)
  end
end
