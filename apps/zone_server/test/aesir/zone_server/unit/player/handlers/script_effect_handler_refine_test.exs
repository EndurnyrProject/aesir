defmodule Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandlerRefineTest do
  @moduledoc """
  The `{:refine, index, nameid, cost_type, use_blessing?}` op end to end: real
  DB, real `RefineOps`, no mocks — mirrors `RefineOpsTest`'s fixtures. Also
  drives `PlayerSession.handle_call({:npc, {:script_apply, op}}, ...)` directly to
  prove the session's reply-shape handling accepts the tagged `RefineOps`
  outcome (not just `{:ok, %PlayerState{}}`).
  """

  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Real item ids from priv/db/items (same fixtures as RefineOpsTest).
  @sword 1101
  @phracon 1010
  @potion 501
  @right_hand 2

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

  describe "{:refine, index, nameid, cost_type, use_blessing?}" do
    test "delegates to RefineOps, mutates the real inventory, and returns the tagged result", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{refine: 0})
      seed_inv(char.id, @phracon, 1)

      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = base_state(char, stats, inventory)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:refine, index, @sword, :normal, false}, state)

      assert reply == {:ok, :success, 1}
      assert %{^index => %InventoryItem{refine: 1}} = new_state.game_state.inventory
      assert new_state.game_state.zeny == 100_000 - 50

      assert [%InventoryItem{refine: 1}] =
               InventoryPersistence.load_inventory(char.id) |> Enum.filter(&(&1.nameid == @sword))
    end

    test "a rejected pre-validation leaves state untouched", %{character: char, stats: stats} do
      seed_inv(char.id, @potion, 1)
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)
      state = base_state(char, stats, inventory)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:refine, index, @potion, :normal, false}, state)

      assert reply == {:error, :not_refinable}
      assert new_state == state
    end

    test "a stale nameid at index is rejected with :no_item", %{character: char, stats: stats} do
      seed_inv(char.id, @sword, 1, %{refine: 0})
      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = base_state(char, stats, inventory)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:refine, index, @potion, :normal, false}, state)

      assert reply == {:error, :no_item}
      assert new_state == state
    end
  end

  describe "PlayerSession.handle_call({:npc, {:script_apply, {:refine, ...}}}, ...)" do
    test "replies with the tagged outcome and keeps it as the session's new state", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{refine: 0})
      seed_inv(char.id, @phracon, 1)

      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = %{connection_pid: self(), game_state: base_state(char, stats, inventory).game_state}

      {:reply, reply, new_state} =
        PlayerSession.handle_call(
          {:npc, {:script_apply, {:refine, index, @sword, :normal, false}}},
          self(),
          state
        )

      assert reply == {:ok, :success, 1}
      assert new_state.game_state.inventory[index].refine == 1
    end

    test "syncs the ETS UnitRegistry with the post-refine state (equipped item stat change)", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{refine: 0, equip: @right_hand})
      seed_inv(char.id, @phracon, 1)

      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)

      equipped_stats = Stats.calculate_stats(stats, char.id, [Map.get(inventory, index)])
      game_state = base_state(char, equipped_stats, inventory).game_state
      state = %{connection_pid: self(), game_state: game_state}

      :ok = UnitRegistry.register_player(game_state, self())

      {:reply, {:ok, :success, 1}, _new_state} =
        PlayerSession.handle_call(
          {:npc, {:script_apply, {:refine, index, @sword, :normal, false}}},
          self(),
          state
        )

      assert {:ok, {PlayerState, registry_state, _pid}} = UnitRegistry.get_unit(:player, char.id)
      assert registry_state.inventory[index].refine == 1
      assert registry_state.stats.combat_stats.atk > game_state.stats.combat_stats.atk
    end
  end

  describe "successrefitem/4 (forced script refine success)" do
    test "raises the equipped item's refine with no ore/zeny cost", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @sword, 1, %{refine: 3, equip: @right_hand})
      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = base_state(char, stats, inventory)

      {reply, new_state} =
        ScriptEffectHandler.apply_op(
          {:successrefitem, index, @sword, 1},
          state
        )

      assert {:ok, game_state} = reply
      assert game_state.inventory[index].refine == 4
      assert new_state.game_state.inventory[index].refine == 4
      assert new_state.game_state.zeny == char.zeny

      assert [%InventoryItem{refine: 4}] =
               InventoryPersistence.load_inventory(char.id) |> Enum.filter(&(&1.nameid == @sword))
    end

    test "passes through a rejected attempt untouched", %{character: char, stats: stats} do
      seed_inv(char.id, @sword, 1, %{refine: 0})
      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = base_state(char, stats, inventory)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:successrefitem, index, @potion, 1}, state)

      assert reply == {:error, :no_item}
      assert new_state == state
    end
  end

  describe "failedrefitem/3 (forced script refine failure)" do
    test "destroys the equipped item and persists the removal", %{character: char, stats: stats} do
      seed_inv(char.id, @sword, 1, %{refine: 7, equip: @right_hand})
      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = base_state(char, stats, inventory)

      {reply, new_state} = ScriptEffectHandler.apply_op({:failedrefitem, index, @sword}, state)

      assert {:ok, game_state} = reply
      refute Map.has_key?(game_state.inventory, index)
      assert new_state.game_state.inventory == %{}

      assert InventoryPersistence.load_inventory(char.id) |> Enum.filter(&(&1.nameid == @sword)) ==
               []
    end

    test "passes through a rejected attempt untouched", %{character: char, stats: stats} do
      seed_inv(char.id, @sword, 1, %{refine: 0})
      inventory = inv_map(char.id)
      index = index_of(inventory, @sword)
      state = base_state(char, stats, inventory)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:failedrefitem, index, @potion}, state)

      assert reply == {:error, :no_item}
      assert new_state == state
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
