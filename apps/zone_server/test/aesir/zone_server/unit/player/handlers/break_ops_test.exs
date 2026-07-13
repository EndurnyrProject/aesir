defmodule Aesir.ZoneServer.Unit.Player.Handlers.BreakOpsTest do
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.BreakOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  # Real item ids from priv/db/items (loaded into :persistent_term at boot).
  # Sword: weapon_level 1, refineable, subtype one_handed_sword.
  @sword 1101

  @right_hand 0x000002

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

  describe "break/2" do
    test "flags the equipped row broken, unequips it, drops its stat contribution, and returns it",
         %{character: char, stats: stats} do
      seed_inv(char.id, @sword, 1, %{equip: @right_hand})

      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)

      equipped_stats = Stats.calculate_stats(stats, char.id, [Map.get(inventory, index)])
      atk_equipped = equipped_stats.combat_stats.atk
      state = build_state(char, equipped_stats, inventory)

      assert {:ok, new_state, %InventoryItem{nameid: @sword} = broken} =
               BreakOps.break(state, :right_hand)

      assert broken.attribute == 1
      assert broken.equip == 0
      assert %{^index => %InventoryItem{attribute: 1, equip: 0}} = new_state.inventory

      assert [%InventoryItem{attribute: 1, equip: 0}] =
               InventoryPersistence.load_inventory(char.id) |> Enum.filter(&(&1.nameid == @sword))

      # The broken weapon no longer contributes atk (it was unequipped).
      assert new_state.stats.combat_stats.atk == stats.combat_stats.atk
      assert new_state.stats.combat_stats.atk < atk_equipped
    end

    test "on an empty slot returns an error and mutates nothing", %{
      character: char,
      stats: stats
    } do
      state = build_state(char, stats, %{})

      assert {:error, _reason} = BreakOps.break(state, :right_hand)
      assert InventoryPersistence.load_inventory(char.id) == []
    end
  end

  describe "repair/2" do
    test "clears the broken flag, leaves the row unequipped, and is idempotent", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{attribute: 1, equip: 0})

      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = build_state(char, stats, inventory)

      assert {:ok, repaired_state} = BreakOps.repair(state, index)
      assert %{^index => %InventoryItem{attribute: 0, equip: 0}} = repaired_state.inventory

      assert [%InventoryItem{attribute: 0, equip: 0}] =
               InventoryPersistence.load_inventory(char.id) |> Enum.filter(&(&1.nameid == @sword))

      # Idempotent: repairing an already-normal row is a no-op success.
      assert {:ok, ^repaired_state} = BreakOps.repair(repaired_state, index)
    end

    test "on a missing index is a no-op success", %{character: char, stats: stats} do
      state = build_state(char, stats, %{})
      assert {:ok, ^state} = BreakOps.repair(state, 42)
    end
  end

  describe "repair_all/1" do
    test "clears every broken row and leaves them unequipped", %{character: char, stats: stats} do
      seed_inv(char.id, @sword, 1, %{attribute: 1, equip: 0})
      seed_inv(char.id, @sword, 1, %{attribute: 1, equip: 0})

      inventory = inv_map(char.id)
      state = build_state(char, stats, inventory)

      assert {:ok, repaired_state} = BreakOps.repair_all(state)

      assert Enum.all?(repaired_state.inventory, fn {_index, item} ->
               item.attribute == 0 and item.equip == 0
             end)

      assert Enum.all?(InventoryPersistence.load_inventory(char.id), &(&1.attribute == 0))

      # Idempotent: nothing broken left to fix.
      assert {:ok, ^repaired_state} = BreakOps.repair_all(repaired_state)
    end

    test "with no broken rows is a no-op success", %{character: char, stats: stats} do
      seed_inv(char.id, @sword, 1, %{attribute: 0})
      inventory = inv_map(char.id)
      state = build_state(char, stats, inventory)

      assert {:ok, ^state} = BreakOps.repair_all(state)
    end
  end

  defp seed_inv(char_id, nameid, amount, attrs) do
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

  defp build_state(character, stats, inventory) do
    %PlayerState{
      character_id: character.id,
      account_id: character.account_id,
      zeny: character.zeny,
      inventory: inventory,
      stats: stats
    }
  end
end
