defmodule Aesir.ZoneServer.Unit.Player.Handlers.RefineOpsTest do
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.InterServer.PubSub
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.RefineOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  # Real item ids from priv/db/items (loaded into :persistent_term at boot).
  # Sword: weapon_level 1, refineable, subtype one_handed_sword.
  @sword 1101
  # Phracon: the weapon-lv1 "normal" ore (refine.yml).
  @phracon 1010
  # HD_Oridecon: the weapon-lv1 "hd" ore (refine.yml).
  @hd_oridecon 6240
  # Bradium: the weapon-lv1 "normal" ore at yml Level 13, the first weapon-lv1
  # refine level with broadcast_success/broadcast_failure set.
  @bradium 6224
  # Blacksmith Blessing: fixed protection item across all levels.
  @blessing 6635
  # A plain non-equipment item: not refineable.
  @potion 501

  @right_hand 2

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(InventoryPersistence)
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
        class: 0,
        base_level: 99,
        zeny: 100_000,
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

  describe "apply/6 - success" do
    test "decrements ore + zeny, increments refine, and recalculates stats for an equipped weapon",
         %{character: char, stats: stats} do
      seed_inv(char.id, @sword, 1, %{refine: 0, equip: @right_hand})
      seed_inv(char.id, @phracon, 1)

      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)

      equipped_stats = Stats.calculate_stats(stats, char.id, [Map.get(inventory, index)])
      atk_before = equipped_stats.combat_stats.atk

      state = build_state(char, equipped_stats, inventory)

      {new_state, result} =
        RefineOps.apply(state, index, @sword, :normal, false, success_roll: 0, break_roll: 9999)

      assert result == {:ok, :success, 1}
      assert new_state.zeny == 100_000 - 50
      assert %{^index => %InventoryItem{refine: 1}} = new_state.inventory
      # Weapon-lv1 yml Level 1: bonus 200 -> atk += 200/100 = 2.
      assert new_state.stats.combat_stats.atk == atk_before + 2

      assert [%InventoryItem{refine: 1}] =
               InventoryPersistence.load_inventory(char.id) |> Enum.filter(&(&1.nameid == @sword))

      assert Aesir.ZoneServer.Unit.Inventory.held_amount(new_state.inventory, @phracon) == 0
      assert Repo.get!(Character, char.id).zeny == 100_000 - 50
    end
  end

  describe "apply/6 - downgrade" do
    test "decrements refine and consumes the hd ore", %{character: char, stats: stats} do
      seed_inv(char.id, @sword, 1, %{refine: 7})
      seed_inv(char.id, @hd_oridecon, 1)

      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = build_state(char, stats, inventory)

      {new_state, result} =
        RefineOps.apply(state, index, @sword, :hd, false, success_roll: 9999, break_roll: 9999)

      assert result == {:ok, :downgrade, 6}
      assert %{^index => %InventoryItem{refine: 6}} = new_state.inventory
      assert new_state.zeny == 100_000 - 20_000
      assert Aesir.ZoneServer.Unit.Inventory.held_amount(new_state.inventory, @hd_oridecon) == 0
    end
  end

  describe "apply/6 - break" do
    test "destroys the inventory row and recalculates stats when the item was equipped", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{refine: 7, equip: @right_hand})
      seed_inv(char.id, @phracon, 1)

      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)

      equipped_stats = Stats.calculate_stats(stats, char.id, [Map.get(inventory, index)])
      state = build_state(char, equipped_stats, inventory)

      {new_state, result} =
        RefineOps.apply(state, index, @sword, :normal, false, success_roll: 9999, break_roll: 0)

      assert result == {:ok, :broke}
      refute Map.has_key?(new_state.inventory, index)
      assert new_state.zeny == 100_000 - 50

      assert InventoryPersistence.load_inventory(char.id)
             |> Enum.filter(&(&1.nameid == @sword)) == []

      # No weapon equipped anymore, so the equipment atk bonus is gone.
      assert new_state.stats.combat_stats.atk == stats.combat_stats.atk
    end
  end

  describe "apply/6 - fail (blessing-protected)" do
    test "consumes ore, zeny, and the blessing but leaves refine unchanged", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{refine: 7})
      seed_inv(char.id, @phracon, 1)
      seed_inv(char.id, @blessing, 1)

      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = build_state(char, stats, inventory)

      {new_state, result} =
        RefineOps.apply(state, index, @sword, :normal, true, success_roll: 9999, break_roll: 0)

      assert result == {:ok, :fail}
      assert %{^index => %InventoryItem{refine: 7}} = new_state.inventory
      assert new_state.zeny == 100_000 - 50
      assert Aesir.ZoneServer.Unit.Inventory.held_amount(new_state.inventory, @phracon) == 0
      assert Aesir.ZoneServer.Unit.Inventory.held_amount(new_state.inventory, @blessing) == 0
    end
  end

  describe "apply/6 - TOCTOU nameid guard" do
    test "a mismatched nameid at index returns :no_item and touches nothing", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{refine: 0})
      seed_inv(char.id, @phracon, 1)

      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = build_state(char, stats, inventory)

      # The caller observed a different item at `index` than what's there now
      # (e.g. it was swapped between the DSL read and this call arriving).
      assert {^state, {:error, :no_item}} = RefineOps.apply(state, index, @potion, :normal)

      assert Repo.get!(Character, char.id).zeny == 100_000

      assert [%InventoryItem{refine: 0}] =
               InventoryPersistence.load_inventory(char.id) |> Enum.filter(&(&1.nameid == @sword))

      assert Aesir.ZoneServer.Unit.Inventory.held_amount(inventory, @phracon) == 1
    end
  end

  describe "apply/6 - transaction rollback" do
    test "a failure inside the transaction after the zeny debit rolls back zeny and inventory", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{refine: 0})
      seed_inv(char.id, @phracon, 1)

      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = build_state(char, stats, inventory)

      # Success rolls guaranteed at weapon-lv1 yml Level 1 (rate 10000), so the
      # ore + zeny debit both run before this forced failure on the refine
      # mutation that follows them in the same transaction.
      stub(InventoryPersistence, :update_item, fn _item, _attrs ->
        {:error, :forced_failure}
      end)

      assert {^state, {:error, :forced_failure}} =
               RefineOps.apply(state, index, @sword, :normal, false,
                 success_roll: 0,
                 break_roll: 9999
               )

      assert Repo.get!(Character, char.id).zeny == 100_000

      assert [%InventoryItem{refine: 0, amount: 1}] =
               InventoryPersistence.load_inventory(char.id) |> Enum.filter(&(&1.nameid == @sword))

      assert [%InventoryItem{amount: 1}] =
               InventoryPersistence.load_inventory(char.id)
               |> Enum.filter(&(&1.nameid == @phracon))
    end
  end

  describe "apply/6 - pre-validation" do
    test "a stale index with no item returns :no_item and touches nothing", %{
      character: char,
      stats: stats
    } do
      state = build_state(char, stats, %{})

      assert {^state, {:error, :no_item}} = RefineOps.apply(state, 0, @sword, :normal)
    end

    test "a non-refinable item returns :not_refinable", %{character: char, stats: stats} do
      seed_inv(char.id, @potion, 1)
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)
      state = build_state(char, stats, inventory)

      assert {^state, {:error, :not_refinable}} =
               RefineOps.apply(state, index, @potion, :normal)
    end

    test "an item already at MAX_REFINE returns :max_refine", %{character: char, stats: stats} do
      seed_inv(char.id, @sword, 1, %{refine: 20})
      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = build_state(char, stats, inventory)

      assert {^state, {:error, :max_refine}} = RefineOps.apply(state, index, @sword, :normal)
    end

    test "insufficient ore returns :no_ore and writes nothing", %{character: char, stats: stats} do
      seed_inv(char.id, @sword, 1, %{refine: 0})
      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = build_state(char, stats, inventory)

      assert {^state, {:error, :no_ore}} = RefineOps.apply(state, index, @sword, :normal)
      assert Repo.get!(Character, char.id).zeny == 100_000
    end

    test "insufficient zeny returns :no_zeny and writes nothing", %{character: char, stats: stats} do
      seed_inv(char.id, @sword, 1, %{refine: 0})
      seed_inv(char.id, @phracon, 1)
      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = build_state(char, stats, inventory, zeny: 0)

      assert {^state, {:error, :no_zeny}} = RefineOps.apply(state, index, @sword, :normal)

      assert Aesir.ZoneServer.Unit.Inventory.held_amount(inventory, @phracon) == 1
    end

    test "requesting blessing without holding one returns :no_blessing", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{refine: 7})
      seed_inv(char.id, @phracon, 1)
      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = build_state(char, stats, inventory)

      assert {^state, {:error, :no_blessing}} =
               RefineOps.apply(state, index, @sword, :normal, true)
    end
  end

  describe "apply/6 - server-wide broadcast" do
    setup do
      PubSub.subscribe_to_announcements()
      :ok
    end

    test "publishes one server_announce on a flagged broadcast_success outcome", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{refine: 12})
      seed_inv(char.id, @bradium, 1)

      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = build_state(char, stats, inventory)

      {_new_state, result} =
        RefineOps.apply(state, index, @sword, :normal, false, success_roll: 0, break_roll: 9999)

      assert result == {:ok, :success, 13}

      assert_receive {:server_announce, event}, 1000
      assert event.message == %{nameid: @sword, refine: 13}
      refute_receive {:server_announce, _other}, 200
    end

    test "publishes one server_announce on a flagged broadcast_failure break outcome", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{refine: 12})
      seed_inv(char.id, @bradium, 1)

      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = build_state(char, stats, inventory)

      {_new_state, result} =
        RefineOps.apply(state, index, @sword, :normal, false,
          success_roll: 9999,
          break_roll: 0
        )

      assert result == {:ok, :broke}

      assert_receive {:server_announce, event}, 1000
      assert event.message == %{nameid: @sword, refine: 12}
      refute_receive {:server_announce, _other}, 200
    end

    test "publishes nothing when the refine level is unflagged", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{refine: 0})
      seed_inv(char.id, @phracon, 1)

      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = build_state(char, stats, inventory)

      {_new_state, result} =
        RefineOps.apply(state, index, @sword, :normal, false, success_roll: 0, break_roll: 9999)

      assert result == {:ok, :success, 1}
      refute_receive {:server_announce, _event}, 200
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

  defp inv_map(char_id) do
    char_id
    |> InventoryPersistence.load_inventory()
    |> PlayerState.from_list()
  end

  defp index_of(map, nameid) do
    Enum.find_value(map, fn {index, item} ->
      if item.nameid == nameid, do: index
    end)
  end

  defp build_state(character, stats, inventory, opts \\ []) do
    %PlayerState{
      character_id: character.id,
      account_id: character.account_id,
      zeny: Keyword.get(opts, :zeny, character.zeny),
      inventory: inventory,
      stats: stats
    }
  end
end
