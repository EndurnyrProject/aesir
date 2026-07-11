defmodule Aesir.ZoneServer.Integration.ConsumableBuffsPhase1IntegrationTest do
  @moduledoc """
  End-to-end coverage that a Phase-1 consumable stat buff changes the observable
  outcome and reverts on expiry, exercising the real item-use path:

    1. Consuming a stat food ("Steamed Tongue", `sc_start :sc_food_str_cash`)
       runs the compiled `on_use` script through `ItemHandler`, applies the
       status in the shared ETS `StatusStorage`, and - via the Task 1 recalc fix
       in `ItemHandler.consume/4` - immediately refreshes the player's stat
       snapshot so the effective STR and the derived ATK it feeds both rise, with
       the change pushed to the client as a `ParamChange`.
    2. When the status expires (the same recalc the `StatusTickManager` triggers,
       driven here deterministically via `remove_status`), the effective STR and
       ATK revert to baseline and a reverting `ParamChange` is pushed.

  Drives the real subsystems (item catalog, script compiler/DSL, status
  interpreter/storage, stat recalc). Only the network transport is faked by the
  `IntegrationCase` connection process; inventory consumption is stubbed so the
  test stays focused on the recalc, not persistence.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.ParamChange
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.ItemHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.Stats

  # "Steamed Tongue": on_use is `sc_start(:sc_food_str_cash, 1800000, 10)` plus a
  # percent heal - a clean single Phase-1 stat buff of +10 STR.
  @food_id 12_202
  @food_str_bonus 10
  @slot 0
  @client_index 2

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(InventoryOps)

    # A sibling async:false test may have swapped the boot-compiled catalog for a
    # single-item set; recompile the real catalog so the food's on_use is present.
    ScriptCompiler.compile_all!()
    :ok
  end

  test "a stat food raises effective STR and derived ATK, then reverts on expiry" do
    player =
      start_player_session(
        id: 9601,
        name: "Eater",
        str: 5,
        base_level: 10
      )

    char_id = player.character.id

    on_exit(fn -> StatusStorage.remove_status(:player, char_id, :sc_food_str_cash) end)

    baseline = get_player_state(player.pid).stats
    baseline_str = Stats.get_effective_stat(baseline, :str)
    baseline_atk = baseline.combat_stats.atk
    flush_packets()

    state = %{game_state: get_player_state(player.pid), connection_pid: player.connection_pid}

    expect(InventoryOps, :remove, fn ^char_id, inventory, @slot, 1 ->
      {:ok, %{@slot => %{inventory[@slot] | amount: 4}}, {:reduced, @slot, 4}}
    end)

    state = put_in(state.game_state.inventory, %{@slot => food_item()})

    assert {:noreply, committed} = ItemHandler.handle_use_item(@client_index, state)

    buffed = committed.game_state.stats
    assert Stats.get_effective_stat(buffed, :str) == baseline_str + @food_str_bonus
    assert buffed.combat_stats.atk > baseline_atk
    assert StatusStorage.has_status?(:player, char_id, :sc_food_str_cash)

    atk_id = StatusParams.atk1()
    assert_receive {:packet_sent, %ParamChange{var_id: ^atk_id, value: buffed_atk}, _}, 1_000
    assert buffed_atk == buffed.combat_stats.atk
    assert buffed_atk > baseline_atk
    flush_packets()

    # Expiry: the StatusTickManager removes the entry and recalcs the session;
    # drive that deterministically through the same recalc entry point.
    StatusInterpreter.remove_status(:player, char_id, :sc_food_str_cash)
    reverted = StatusManager.recalculate_after_status_change(committed).game_state.stats

    assert Stats.get_effective_stat(reverted, :str) == baseline_str
    assert reverted.combat_stats.atk == baseline_atk

    assert_receive {:packet_sent, %ParamChange{var_id: ^atk_id, value: reverted_atk}, _}, 1_000
    assert reverted_atk == baseline_atk
  end

  defp food_item, do: %InventoryItem{id: 1, nameid: @food_id, amount: 5}
end
