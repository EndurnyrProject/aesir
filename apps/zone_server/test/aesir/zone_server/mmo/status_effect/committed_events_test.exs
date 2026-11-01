defmodule Aesir.ZoneServer.Mmo.StatusEffect.CommittedEventsTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule PlainStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_events_plain,
      target_types: [:player],
      no_dispel: false,
      no_clear_buff: false
  end

  defmodule CureOnlyStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_events_cure,
      target_types: [:player],
      no_dispel: false,
      no_clear_buff: false

    @impl true
    def before_overlap(_target, _instance, _context), do: {:end_only, [:sc_test_events_plain]}
  end

  defmodule ChainedStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_events_chained,
      target_types: [:player],
      no_dispel: false,
      no_clear_buff: false,
      end_on_end: [:sc_test_events_plain]
  end

  defmodule ActionStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_events_action,
      target_types: [:player],
      no_dispel: false,
      no_clear_buff: false

    @impl true
    def before_overlap(_target, %{state: %{ends: ends}}, _context),
      do: {:continue, Enum.map(ends, &{:end_status, &1})}
  end

  defmodule KillingEndStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_events_killing_end,
      target_types: [:player],
      no_dispel: false,
      no_clear_buff: false

    alias Aesir.ZoneServer.Unit.UnitRegistry

    @impl true
    def on_expire({:player, id}, _instance, _context) do
      {:ok, {_module, player, _pid}} = UnitRegistry.get_unit(:player, id)
      stats = %{player.stats | current_state: %{player.stats.current_state | hp: 0}}
      UnitRegistry.update_unit_state(:player, id, %{player | stats: stats})
    end
  end

  defmodule ReplacingStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_events_replacing,
      target_types: [:player],
      no_dispel: false,
      no_clear_buff: false,
      end_on_start: [:sc_test_events_chained]
  end

  setup :setup_ets_tables

  setup do
    player =
      PlayerStateFixture.build(%{
        character_id: 7_701,
        account_id: 7_701,
        stats: %{combat_stats: %CombatStats{}}
      })

    :ok = UnitRegistry.register_player(player, self())
    :ok = Registry.register_module(PlainStatus)
    %{player_id: player.character_id}
  end

  test "committed events distinguish a stored application, retained overlap and absent removal",
       %{
         player_id: id
       } do
    params = [duration: 30_000, val1: 5, bypass_resistance: true]

    assert {:ok, [{:sc_test_events_plain, :apply}]} =
             Interpreter.apply_status_with_events(:player, id, :sc_test_events_plain, params)

    held = StatusStorage.get_status(:player, id, :sc_test_events_plain)

    assert {:ok, []} =
             Interpreter.apply_status_with_events(
               :player,
               id,
               :sc_test_events_plain,
               Keyword.put(params, :val1, 1)
             )

    assert StatusStorage.get_status(:player, id, :sc_test_events_plain) == held

    assert {:ok, [{:sc_test_events_plain, :removed}]} =
             Interpreter.remove_status_with_events(:player, id, :sc_test_events_plain, [])

    assert {:ok, []} =
             Interpreter.remove_status_with_events(:player, id, :sc_test_events_plain, [])
  end

  test "committed events distinguish cure-only, retained overlap and mutation-before-failure", %{
    player_id: id
  } do
    :ok = Registry.register_module(CureOnlyStatus)
    :ok = StatusStorage.apply_status(:player, id, :sc_test_events_plain, val1: 5)

    assert {:ok, [{:sc_test_events_plain, :removed}]} =
             Interpreter.apply_status_with_events(:player, id, :sc_test_events_cure,
               duration: 30_000,
               bypass_resistance: true
             )

    refute StatusStorage.has_status?(:player, id, :sc_test_events_plain)
    refute StatusStorage.has_status?(:player, id, :sc_test_events_cure)

    :ok = Registry.register_module(ActionStatus)
    :ok = Registry.register_module(KillingEndStatus)
    :ok = StatusStorage.apply_status(:player, id, :sc_test_events_plain)

    assert {:ok, [{:sc_test_events_plain, :removed}, {:sc_test_events_action, :apply}]} =
             Interpreter.apply_status_with_events(:player, id, :sc_test_events_action,
               duration: 30_000,
               bypass_resistance: true,
               state: %{ends: [:sc_test_events_plain]}
             )

    :ok = Interpreter.remove_status(:player, id, :sc_test_events_action)
    :ok = StatusStorage.apply_status(:player, id, :sc_test_events_killing_end)

    assert {:error, :target_dead, [{:sc_test_events_killing_end, :removed}]} =
             Interpreter.apply_status_with_events(:player, id, :sc_test_events_action,
               duration: 30_000,
               bypass_resistance: true,
               state: %{ends: [:sc_test_events_killing_end]}
             )

    refute StatusStorage.has_status?(:player, id, :sc_test_events_action)
  end

  test "removal includes committed end-on-end changes", %{player_id: id} do
    :ok = Registry.register_module(ChainedStatus)
    :ok = StatusStorage.apply_status(:player, id, :sc_test_events_plain)
    :ok = StatusStorage.apply_status(:player, id, :sc_test_events_chained)

    assert {:ok, [{:sc_test_events_chained, :removed}, {:sc_test_events_plain, :removed}]} =
             Interpreter.remove_status_with_events(:player, id, :sc_test_events_chained, [])

    refute StatusStorage.has_status?(:player, id, :sc_test_events_plain)
  end

  test "end-on-start changes are retained for stored and level-protected applications", %{
    player_id: id
  } do
    :ok = Registry.register_module(ChainedStatus)
    :ok = Registry.register_module(ReplacingStatus)
    :ok = StatusStorage.apply_status(:player, id, :sc_test_events_plain)
    :ok = StatusStorage.apply_status(:player, id, :sc_test_events_chained)

    params = [duration: 30_000, val1: 5, bypass_resistance: true]

    assert {:ok,
            [
              {:sc_test_events_chained, :removed},
              {:sc_test_events_plain, :removed},
              {:sc_test_events_replacing, :apply}
            ]} =
             Interpreter.apply_status_with_events(:player, id, :sc_test_events_replacing, params)

    held = StatusStorage.get_status(:player, id, :sc_test_events_replacing)
    :ok = StatusStorage.apply_status(:player, id, :sc_test_events_plain)
    :ok = StatusStorage.apply_status(:player, id, :sc_test_events_chained)

    assert {:ok, [{:sc_test_events_chained, :removed}, {:sc_test_events_plain, :removed}]} =
             Interpreter.apply_status_with_events(
               :player,
               id,
               :sc_test_events_replacing,
               Keyword.put(params, :val1, 1)
             )

    assert StatusStorage.get_status(:player, id, :sc_test_events_replacing) == held
  end
end
