defmodule Aesir.ZoneServer.Unit.Player.Handlers.ItemEffectsIntegrationTest do
  @moduledoc """
  Drives real catalog items through the compiled `on_use` pipeline end-to-end:
  a healing potion, the bespoke Dead Branch summon, and the class-conditional
  Worn Out Scroll. The scripts are the real ones compiled by `ScriptCompiler`
  from the YAML data, so a regression in either the data or the DSL fails here.
  """
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.ItemUseResult
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.ItemHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @slot 0
  @client_index 2
  @red_potion_id 501
  @dead_branch_id 604
  @worn_out_scroll_id 618

  # Real catalog scripts are shared mutable state via the generated
  # CompiledItemScripts module, so stubs stay process-local and async is off.
  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(Items)
    Mimic.copy(InventoryOps)
    Mimic.copy(Coordinator)
    Mimic.copy(MobManagement)
    Mimic.copy(StatusInterpreter)

    stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)

    # A sibling async:false test may have replaced the boot-compiled
    # CompiledItemScripts with a single-item set; recompile the real catalog so
    # these end-to-end tests run against the actual item scripts.
    ScriptCompiler.compile_all!()

    :ok
  end

  describe "Red Potion" do
    test "restores HP and consumes exactly one unit end-to-end" do
      {:ok, definition} = Items.by_id(@red_potion_id)
      stub(Items, :by_id, fn @red_potion_id -> {:ok, definition} end)

      expect(InventoryOps, :remove, fn 1000, inventory, @slot, 1 ->
        {:ok, %{@slot => %{inventory[@slot] | amount: 4}}, {:reduced, @slot, 4}}
      end)

      state = state_with(@red_potion_id)

      assert {:noreply, committed} = ItemHandler.handle_use_item(@client_index, state)

      new_hp = committed.game_state.stats.current_state.hp
      assert new_hp in 145..165
      assert committed.game_state.inventory[@slot].amount == 4

      assert_received {:send, :gameplay, {:item_removed, %ItemRemoved{amount: 1}}}
      assert_received {:send, :gameplay, {:item_use_result, %ItemUseResult{ok: true}}}
    end
  end

  describe "Dead Branch" do
    test "summons a mob at the player's cell and consumes one unit" do
      {:ok, definition} = Items.by_id(@dead_branch_id)
      stub(Items, :by_id, fn @dead_branch_id -> {:ok, definition} end)

      stub(MobManagement, :get_all_mobs, fn -> [%{id: 1002}] end)

      expect(Coordinator, :summon_mob, fn "prontera", 1002, 50, 50, opts ->
        assert Keyword.get(opts, :aggressive) == true
        {:ok, 7777}
      end)

      expect(InventoryOps, :remove, fn 1000, inventory, @slot, 1 ->
        {:ok, %{@slot => %{inventory[@slot] | amount: 4}}, {:reduced, @slot, 4}}
      end)

      state = state_with(@dead_branch_id)

      assert {:noreply, committed} = ItemHandler.handle_use_item(@client_index, state)

      assert committed.game_state.inventory[@slot].amount == 4
      assert_received {:send, :gameplay, {:item_use_result, %ItemUseResult{ok: true}}}
    end
  end

  describe "Worn Out Scroll class branching" do
    for {job_id, class, status} <- [{2, :mage, :sc_increaseagi}, {1, :swordman, :sc_blessing}] do
      test "a #{class} gains #{status}" do
        {:ok, definition} = Items.by_id(@worn_out_scroll_id)
        stub(Items, :by_id, fn @worn_out_scroll_id -> {:ok, definition} end)

        test_pid = self()

        stub(StatusInterpreter, :apply_status, fn :player, 1000, applied, _params ->
          send(test_pid, {:status_applied, applied})
          :ok
        end)

        expect(InventoryOps, :remove, fn 1000, inventory, @slot, 1 ->
          {:ok, %{@slot => %{inventory[@slot] | amount: 4}}, {:reduced, @slot, 4}}
        end)

        state = state_with(@worn_out_scroll_id, unquote(job_id))

        assert {:noreply, _committed} = ItemHandler.handle_use_item(@client_index, state)

        assert_received {:status_applied, unquote(status)}
        assert_received {:send, :gameplay, {:item_use_result, %ItemUseResult{ok: true}}}
      end
    end
  end

  describe "boot compile" do
    test "compiling the full real item set succeeds" do
      assert ScriptCompiler.compile_all!() == :ok
    end
  end

  defp state_with(nameid, job_id \\ 0) do
    item = %InventoryItem{id: 1, nameid: nameid, amount: 5}

    %{
      connection_pid: self(),
      game_state: %PlayerState{
        character_id: 1000,
        account_id: 2000,
        sex: "M",
        x: 50,
        y: 50,
        map_name: "prontera",
        inventory: %{@slot => item},
        stats: stats(job_id)
      }
    }
  end

  defp stats(job_id) do
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
        job_id: job_id
      }
    }
  end
end
