defmodule Aesir.ZoneServer.Unit.Player.Handlers.ItemHandlerTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.UseItem
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.ItemHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Client index 2 maps to server index 0 (the +2 offset).
  @red_potion_slot 0
  @red_potion_client_index 2
  @red_potion_id 501
  @warp_item_id 502

  # Private mode (not global) keeps stubs process-local so background mob
  # sessions never hit them; async stays false because each test redefines the
  # shared `CompiledItemScripts` module via `ScriptCompiler.compile_all!/1`.
  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(Items)
    Mimic.copy(InventoryOps)

    stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)

    :ok
  end

  describe "handle_use_item/2 with a usable item" do
    test "raises HP, consumes one unit, and sends ItemUseResult{ok: true}" do
      ScriptCompiler.compile_all!([item_def(@red_potion_id, "heal(ctx, hp: 50)")])

      state = state_with_potion()
      definition = usable_definition(@red_potion_id, "heal(ctx, hp: 50)")

      stub(Items, :by_id, fn @red_potion_id -> {:ok, definition} end)

      expect(InventoryOps, :remove, fn 1000, inventory, @red_potion_slot, 1 ->
        {:ok, %{@red_potion_slot => %{inventory[@red_potion_slot] | amount: 4}},
         {:reduced, @red_potion_slot, 4}}
      end)

      assert {:noreply, committed} =
               ItemHandler.handle_use_item(@red_potion_client_index, state)

      assert committed.game_state.stats.current_state.hp == 150
      assert committed.game_state.inventory[@red_potion_slot].amount == 4

      assert_received {:send, :gameplay, {:item_removed, %ItemRemoved{amount: 1}}}

      assert_received {:send, :gameplay,
                       {:item_use_result,
                        %ItemUseResult{index: @red_potion_client_index, ok: true, reason: 0}}}
    end
  end

  describe "handle_use_item/2 with a non-usable item" do
    test "sends ItemUseResult{ok: false}, consumes nothing" do
      definition = %{usable_definition(@red_potion_id, nil) | on_use: nil}

      stub(Items, :by_id, fn @red_potion_id -> {:ok, definition} end)
      reject(&InventoryOps.remove/4)

      state = state_with_potion()

      assert {:noreply, ^state} = ItemHandler.handle_use_item(@red_potion_client_index, state)

      assert_received {:send, :gameplay,
                       {:item_use_result,
                        %ItemUseResult{index: @red_potion_client_index, ok: false}}}

      refute_received {:send, :gameplay, {:item_removed, _}}
    end
  end

  describe "handle_use_item/2 with an effect that halts" do
    test "sends ItemUseResult{ok: false}, consumes nothing" do
      warp_source = ~s|warp(ctx, "nowhere", 0, 0)|
      ScriptCompiler.compile_all!([item_def(@warp_item_id, warp_source)])

      definition = usable_definition(@warp_item_id, warp_source)
      stub(Items, :by_id, fn @warp_item_id -> {:ok, definition} end)
      stub(WarpHandler, :warp, fn _session, _map, _x, _y -> {:error, :map_not_found} end)
      reject(&InventoryOps.remove/4)

      state = state_with_potion(@warp_item_id)

      assert {:noreply, ^state} = ItemHandler.handle_use_item(@red_potion_client_index, state)

      assert_received {:send, :gameplay,
                       {:item_use_result,
                        %ItemUseResult{index: @red_potion_client_index, ok: false}}}

      refute_received {:send, :gameplay, {:item_removed, _}}
    end
  end

  describe "handle_use_item/2 with an empty slot" do
    test "sends ItemUseResult{ok: false} without crashing" do
      reject(&Items.by_id/1)
      reject(&InventoryOps.remove/4)

      state = %{connection_pid: self(), game_state: %{base_state() | inventory: %{}}}

      assert {:noreply, ^state} = ItemHandler.handle_use_item(@red_potion_client_index, state)

      assert_received {:send, :gameplay,
                       {:item_use_result,
                        %ItemUseResult{index: @red_potion_client_index, ok: false}}}
    end
  end

  describe "packet dispatch" do
    test "a UseItem packet casts {:use_item, index}" do
      state = %{game_state: %PlayerState{character_id: 1000}}

      assert {:noreply, ^state} =
               PacketHandler.handle_message(%UseItem{index: @red_potion_client_index}, state)

      assert_received {:"$gen_cast", {:use_item, @red_potion_client_index}}
    end
  end

  defp state_with_potion(nameid \\ @red_potion_id) do
    item = %InventoryItem{id: 1, nameid: nameid, amount: 5}
    inventory = %{@red_potion_slot => item}

    %{connection_pid: self(), game_state: %{base_state() | inventory: inventory}}
  end

  defp base_state do
    %PlayerState{
      character_id: 1000,
      account_id: 2000,
      sex: "M",
      x: 50,
      y: 50,
      map_name: "prontera",
      stats: stats(),
      inventory: %{}
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

  defp item_def(id, on_use) do
    %ItemDefinition{id: id, aegis_name: "Item_#{id}", name: "Item #{id}", on_use: on_use}
  end

  defp usable_definition(id, on_use) do
    %ItemDefinition{
      id: id,
      aegis_name: "Item_#{id}",
      name: "Item #{id}",
      type: :healing,
      on_use: on_use
    }
  end
end
