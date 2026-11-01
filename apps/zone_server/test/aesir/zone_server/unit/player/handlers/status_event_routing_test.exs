defmodule Aesir.ZoneServer.Unit.Player.Handlers.StatusEventRoutingTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ParamChange
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl.PlayerEffects
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  defmodule TransientFlee do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_routing_flee,
      target_types: [:player],
      no_dispel: false,
      no_clear_buff: false

    @impl true
    def modifiers(_instance, _context), do: %{flee: 50}
  end

  defmodule CureFlee do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_routing_cure,
      target_types: [:player],
      no_dispel: false,
      no_clear_buff: false

    @impl true
    def on_apply(_target, _instance, _context), do: {:end_only, [:sc_test_routing_flee]}
  end

  setup :setup_ets_tables

  setup do
    character = %Character{
      id: 7_703,
      account_id: 7_703,
      name: "Status events",
      class: 0,
      base_level: 1,
      job_level: 1,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      hp: 40,
      sp: 11,
      last_map: "prontera",
      last_x: 100,
      last_y: 100
    }

    player = PlayerState.new(character)
    :ok = UnitRegistry.register_player(player, self())
    :ok = Registry.register_module(TransientFlee)
    %{state: %SessionState{game_state: player, connection_pid: self()}}
  end

  test "empty event refresh leaves flee unchanged across apply and expiry", %{state: state} do
    id = state.game_state.character_id
    before = state.game_state.stats
    :ok = StatusStorage.apply_status(:player, id, :sc_test_routing_flee)

    applied = StatusManager.refresh_events(state, [{:sc_intravision, :apply}])
    assert applied.game_state.stats.combat_stats.flee == before.combat_stats.flee
    assert applied.game_state.stats.generation == before.generation
    assert applied.game_state.stats.modifiers.status_effects.flee == 50
    refute_receive {:send, :gameplay, {:param_change, %ParamChange{}}}, 0

    :ok = StatusStorage.remove_status(:player, id, :sc_test_routing_flee)
    removed = StatusManager.refresh_events(applied, [{:sc_partyflee, :removed}])
    assert removed.game_state.stats.combat_stats.flee == before.combat_stats.flee
    assert removed.game_state.stats.generation == before.generation
    refute_receive {:send, :gameplay, {:param_change, %ParamChange{}}}, 0
    assert StatusManager.refresh_events(removed, []) == removed
  end

  test "inline retained status start does not trigger a second full fold", %{state: state} do
    id = state.game_state.character_id
    before = state.game_state.stats
    :ok = StatusStorage.apply_status(:player, id, :sc_test_routing_flee, val1: 5)
    context = Ctx.from_session(state, {:item, 12033})

    kept = PlayerEffects.sc_start(context, :sc_test_routing_flee, 30_000, 1)

    assert kept.game_state.stats.combat_stats.flee == before.combat_stats.flee
    assert kept.game_state.stats.generation == before.generation
    assert kept.session_state == state
    refute_receive {:send, :gameplay, {:param_change, %ParamChange{}}}, 0
  end

  test "external notifications and expiry retain the committed status identity", %{state: state} do
    id = state.game_state.character_id
    :ok = PubSub.subscribe(Aesir.PubSub, "player:#{id}")

    assert {:ok, [{:sc_test_routing_flee, :apply}]} =
             Interpreter.apply_status_with_events(:player, id, :sc_test_routing_flee,
               duration: 30_000,
               bypass_resistance: true,
               owner_refresh: :notify
             )

    assert_receive {:stats, {:status_changed, :sc_test_routing_flee, :apply}}
    refute_receive {:stats, :status_changed}, 0

    held = StatusStorage.get_status(:player, id, :sc_test_routing_flee)
    due = System.monotonic_time(:millisecond) - 1
    expired = %{held | expires_at: due}
    assert StatusStorage.replace_status_if_current(:player, id, held.type, held, expired)
    key = {:player, id, held.type}
    timer_state = %StatusTickManager.State{timers: %{key => {make_ref(), held.generation, due}}}

    assert {:noreply, _} =
             StatusTickManager.handle_info(
               {:status_timer, key, held.generation, due},
               timer_state
             )

    assert_receive {:stats, {:status_changed, :sc_test_routing_flee, :removed}}
    refute_receive {:stats, :status_changed}, 0
    refute StatusStorage.has_status?(:player, id, held.type)
  end

  test "inline cure and removal update subsequent reads before returning", %{state: state} do
    id = state.game_state.character_id
    :ok = Registry.register_module(CureFlee)
    context = Ctx.from_session(state, {:item, 12033})
    :ok = StatusStorage.apply_status(:player, id, :sc_test_routing_flee)
    cached = StatusManager.refresh_events(state, [{:sc_intravision, :apply}])
    context = %{context | game_state: cached.game_state, session_state: cached}
    assert context.game_state.stats.modifiers.status_effects.flee == 50

    cured = PlayerEffects.sc_start(context, :sc_test_routing_cure, 30_000, 1)
    refute Map.has_key?(cured.game_state.stats.modifiers.status_effects, :flee)
    refute StatusStorage.has_status?(:player, id, :sc_test_routing_cure)
    assert cured.game_state.stats.combat_stats.flee == state.game_state.stats.combat_stats.flee

    :ok = StatusStorage.apply_status(:player, id, :sc_test_routing_flee)
    cached = StatusManager.refresh_events(cured.session_state, [{:sc_intravision, :apply}])
    context = %{cured | game_state: cached.game_state, session_state: cached}
    removed = PlayerEffects.sc_end(context, :sc_test_routing_flee)
    refute Map.has_key?(removed.game_state.stats.modifiers.status_effects, :flee)
    assert removed.game_state.stats.combat_stats.flee == state.game_state.stats.combat_stats.flee
  end
end
