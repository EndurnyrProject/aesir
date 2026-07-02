defmodule Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandlerTest do
  @moduledoc """
  The single-writer effect seam: `{:script_apply, op}` applied to the
  authoritative session `PlayerState`. Each op mutates state, persists, and
  pushes the relevant proto to the client, returning the fresh `game_state` (or
  an error that mutates nothing).
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.ParamChange
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @sphmask_id 7114
  @zeny_param 20

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(Items)
    Mimic.copy(InventoryOps)
    Mimic.copy(CharacterPersistence)
    Mimic.copy(Broadcast)
    Mimic.copy(UnitRegistry)

    stub(CharacterPersistence, :update_character, fn _, _, _ -> {:ok, %Character{}} end)
    stub(Broadcast, :to_player, fn _char_id, _packet -> :ok end)
    stub(Broadcast, :to_visible_players, fn _game_state, _packet, _opts -> :ok end)
    stub(UnitRegistry, :update_unit_state, fn :player, _char_id, _game_state -> :ok end)
    :ok
  end

  describe "{:set_char_var, key, value}" do
    test "puts the string-keyed value into vars, persists, and returns the new game_state" do
      test_pid = self()

      expect(CharacterPersistence, :update_character, fn 1000, %{vars: vars}, async: true ->
        send(test_pid, {:persisted_vars, vars})
        {:ok, %Character{}}
      end)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:set_char_var, :sphmask_q, 1}, base_state())

      assert {:ok, game_state} = reply
      assert game_state.vars == %{"sphmask_q" => 1}
      assert new_state.game_state.vars == %{"sphmask_q" => 1}
      assert_received {:persisted_vars, %{"sphmask_q" => 1}}
    end
  end

  describe "{:pay_zeny, amount}" do
    test "debits, pushes the zeny param, persists, returns the new game_state" do
      test_pid = self()

      expect(CharacterPersistence, :update_character, fn 1000, %{zeny: zeny}, async: true ->
        send(test_pid, {:persisted_zeny, zeny})
        {:ok, %Character{}}
      end)

      {reply, new_state} = ScriptEffectHandler.apply_op({:pay_zeny, 500}, base_state(zeny: 1_000))

      assert {:ok, game_state} = reply
      assert game_state.zeny == 500
      assert new_state.game_state.zeny == 500
      assert_received {:send, _ch, {:param_change, %ParamChange{var_id: @zeny_param, value: 500}}}
      assert_received {:persisted_zeny, 500}
    end

    test "rejects :not_enough_zeny when short and debits nothing" do
      reject(&CharacterPersistence.update_character/3)

      state = base_state(zeny: 100)
      {reply, new_state} = ScriptEffectHandler.apply_op({:pay_zeny, 500}, state)

      assert reply == {:error, :not_enough_zeny}
      assert new_state == state
      refute_received {:send, _ch, {:param_change, _}}
    end
  end

  describe "{:credit_zeny, amount}" do
    test "credits, pushes the zeny param, persists, returns the new game_state" do
      test_pid = self()

      expect(CharacterPersistence, :update_character, fn 1000, %{zeny: zeny}, async: true ->
        send(test_pid, {:persisted_zeny, zeny})
        {:ok, %Character{}}
      end)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:credit_zeny, 500}, base_state(zeny: 1_000))

      assert {:ok, game_state} = reply
      assert game_state.zeny == 1_500
      assert new_state.game_state.zeny == 1_500

      assert_received {:send, _ch,
                       {:param_change, %ParamChange{var_id: @zeny_param, value: 1_500}}}

      assert_received {:persisted_zeny, 1_500}
    end

    test "clamps the credited total to MAX_ZENY" do
      {reply, new_state} =
        ScriptEffectHandler.apply_op({:credit_zeny, 500}, base_state(zeny: 999_999_999))

      assert {:ok, game_state} = reply
      assert game_state.zeny == 1_000_000_000
      assert new_state.game_state.zeny == 1_000_000_000
    end
  end

  describe "{:give_item, item_id, qty}" do
    test "adds via InventoryOps, emits ItemAdded, returns the new game_state" do
      definition = item_definition(@sphmask_id)
      stub(Items, :by_id, fn @sphmask_id -> {:ok, definition} end)

      added = %InventoryItem{nameid: @sphmask_id, amount: 1}

      expect(InventoryOps, :add, fn 1000, %{}, _stats, ^definition, 1 ->
        {:ok, %{0 => added}, {:added, 0, added}}
      end)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:give_item, @sphmask_id, 1}, base_state())

      assert {:ok, game_state} = reply
      assert game_state.inventory == %{0 => added}
      assert new_state.game_state.inventory == %{0 => added}
      assert_received {:send, _ch, {:item_added, %ItemAdded{}}}
    end

    test "rejects :inventory_full and mutates nothing" do
      definition = item_definition(@sphmask_id)
      stub(Items, :by_id, fn @sphmask_id -> {:ok, definition} end)
      stub(InventoryOps, :add, fn _, _, _, _, _ -> {:error, :inventory_full} end)

      state = base_state()
      {reply, new_state} = ScriptEffectHandler.apply_op({:give_item, @sphmask_id, 1}, state)

      assert reply == {:error, :inventory_full}
      assert new_state == state
      refute_received {:send, _ch, {:item_added, _}}
    end

    test "rejects :item_not_found for an unknown item id" do
      stub(Items, :by_id, fn _ -> :error end)
      reject(&InventoryOps.add/6)

      state = base_state()
      {reply, new_state} = ScriptEffectHandler.apply_op({:give_item, 9_999_999, 1}, state)

      assert reply == {:error, :item_not_found}
      assert new_state == state
    end
  end

  describe "{:delitem, item_id, qty}" do
    test "removes the held stack via InventoryOps, emits ItemRemoved, returns new game_state" do
      held = %InventoryItem{id: 1, nameid: @sphmask_id, amount: 3}
      state = base_state(inventory: %{0 => held})

      expect(InventoryOps, :remove, fn 1000, %{0 => ^held}, 0, 2 ->
        {:ok, %{0 => %{held | amount: 1}}, {:reduced, 0, 1}}
      end)

      {reply, new_state} = ScriptEffectHandler.apply_op({:delitem, @sphmask_id, 2}, state)

      assert {:ok, game_state} = reply
      assert game_state.inventory[0].amount == 1
      assert new_state.game_state.inventory[0].amount == 1
      assert_received {:send, _ch, {:item_removed, %ItemRemoved{amount: 2}}}
    end

    test "rejects :not_enough_items when the player holds fewer, mutating nothing" do
      state = base_state(inventory: %{0 => %InventoryItem{nameid: @sphmask_id, amount: 1}})
      reject(&InventoryOps.remove/4)

      {reply, new_state} = ScriptEffectHandler.apply_op({:delitem, @sphmask_id, 5}, state)

      assert reply == {:error, :not_enough_items}
      assert new_state == state
      refute_received {:send, _ch, {:item_removed, _}}
    end
  end

  describe "{:change_job, job_id}" do
    test "updates progression.job_id and returns the new game_state" do
      {:ok, knight_id} = AvailableJobs.job_name_to_id(:knight)

      {reply, new_state} =
        ScriptEffectHandler.apply_op({:change_job, knight_id}, job_change_state())

      assert {:ok, game_state} = reply
      assert game_state.stats.progression.job_id == knight_id
      assert new_state.game_state.stats.progression.job_id == knight_id
    end

    test "rejects :unknown_job and mutates nothing" do
      reject(&CharacterPersistence.update_character/3)

      state = job_change_state()
      {reply, new_state} = ScriptEffectHandler.apply_op({:change_job, 99_999}, state)

      assert reply == {:error, :unknown_job}
      assert new_state == state
    end
  end

  defp job_change_state do
    character = %Character{
      id: 1000,
      account_id: 2000,
      name: "Swordy",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 10,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 50,
      job_level: 50,
      class: 0
    }

    %{connection_pid: self(), game_state: PlayerState.new(character)}
  end

  defp base_state(opts \\ []) do
    %{
      connection_pid: self(),
      game_state: %PlayerState{
        character_id: 1000,
        account_id: 2000,
        zeny: Keyword.get(opts, :zeny, 0),
        vars: Keyword.get(opts, :vars, %{}),
        temp_vars: %{},
        inventory: Keyword.get(opts, :inventory, %{}),
        stats: stats()
      }
    }
  end

  defp stats do
    %Aesir.ZoneServer.Unit.Player.Stats{
      current_state: %Aesir.ZoneServer.Unit.Stats.CurrentState{hp: 100, sp: 10},
      derived_stats: %Aesir.ZoneServer.Unit.Stats.DerivedStats{
        max_hp: 500,
        max_sp: 200,
        aspd: 150
      },
      progression: %Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression{
        base_level: 10,
        job_level: 3,
        job_id: 0
      }
    }
  end

  defp item_definition(id) do
    %ItemDefinition{id: id, aegis_name: "Item_#{id}", name: "Item #{id}", weight: 10}
  end
end
