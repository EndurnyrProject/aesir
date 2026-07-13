defmodule Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandlerRepairTest do
  @moduledoc """
  The `{:repair, index}` / `{:repairall}` ops end to end: real DB, real
  `BreakOps`, no mocks - mirrors `ScriptEffectHandlerRefineTest`'s fixtures.
  Asserts broken rows become normal (`attribute == 0`), stay unequipped
  (`equip == 0`, repair never re-wears), and that the now-normal row is synced
  back to the owning client via `InventoryView.item_added/2`.
  """

  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemAdded
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  # Real item ids from priv/db/items (same fixtures as RefineOpsTest).
  @sword 1101
  @armor 2302
  @potion 501

  setup :setup_ets_tables

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

    %{character: character, stats: Stats.from_character(character)}
  end

  describe "{:repair, index}" do
    test "clears the broken flag, keeps the row unequipped, and syncs it", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{attribute: 1, equip: 0})
      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = base_state(char, stats, inventory)

      {reply, new_state} = ScriptEffectHandler.apply_op({:repair, index}, state)

      assert {:ok, %PlayerState{}} = reply
      assert %{^index => %InventoryItem{attribute: 0, equip: 0}} = new_state.game_state.inventory
      assert_receive {:send, :gameplay, {:item_added, %ItemAdded{attribute: 0}}}

      assert [%InventoryItem{attribute: 0}] =
               InventoryPersistence.load_inventory(char.id) |> Enum.filter(&(&1.nameid == @sword))
    end

    test "a non-broken row is an idempotent no-op success with no sync", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @potion, 1)
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)
      state = base_state(char, stats, inventory)

      {reply, new_state} = ScriptEffectHandler.apply_op({:repair, index}, state)

      assert {:ok, %PlayerState{}} = reply
      assert new_state.game_state.inventory == inventory
      refute_receive {:send, :gameplay, {:item_added, _}}
    end
  end

  describe "{:repairall}" do
    test "clears every broken row, leaves them unequipped, and syncs each", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{attribute: 1, equip: 0})
      seed_inv(char.id, @armor, 1, %{attribute: 1, equip: 0})
      seed_inv(char.id, @potion, 1)
      inventory = inv_map(char.id)
      state = base_state(char, stats, inventory)

      {reply, new_state} = ScriptEffectHandler.apply_op({:repairall}, state)

      assert {:ok, %PlayerState{}} = reply

      broken =
        for {_index, %InventoryItem{attribute: attr, equip: equip}} <-
              new_state.game_state.inventory,
            attr == 1 or equip != 0,
            do: attr

      assert broken == []
      assert_receive {:send, :gameplay, {:item_added, %ItemAdded{attribute: 0}}}
      assert_receive {:send, :gameplay, {:item_added, %ItemAdded{attribute: 0}}}
    end

    test "a clean inventory is an idempotent no-op success with no sync", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @potion, 1)
      inventory = inv_map(char.id)
      state = base_state(char, stats, inventory)

      {reply, new_state} = ScriptEffectHandler.apply_op({:repairall}, state)

      assert {:ok, %PlayerState{}} = reply
      assert new_state.game_state.inventory == inventory
      refute_receive {:send, :gameplay, {:item_added, _}}
    end
  end

  defp seed_inv(char_id, nameid, amount, attrs \\ %{}) do
    InventoryPersistence.insert_item(char_id, Map.merge(%{nameid: nameid, amount: amount}, attrs))
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

  defp base_state(character, stats, inventory) do
    %{
      connection_pid: self(),
      game_state: %PlayerState{
        character_id: character.id,
        account_id: character.account_id,
        zeny: character.zeny,
        inventory: inventory,
        stats: stats
      }
    }
  end
end
