defmodule Aesir.ZoneServer.Npc.OnTouchTest do
  @moduledoc """
  End-to-end coverage of NPC trigger areas: player movement checks the
  per-map touch rects (`Npc.Registry.touch_rects/1`) on every cell change and
  fires the owning NPC's `OnTouch_` (one toucher at a time, never for a
  concealed player) or `OnTouch` as an attached `Interaction`, or falls back
  to `on_talk/1` when the module declares a trigger area but no touch label
  (rAthena warper behavior). Also covers the other scan triggers (knockback,
  map load, concealment end), the `OnTouch_` handoff on leave, and the event
  queue a busy player's touches wait in.

  Drives the real `MovementHandler.handle_movement_tick/1` ->
  `MovementHandler` path, mirroring `warp_integration_test.exs`'s
  movement-driven trigger pattern and `npc_visibility_test.exs`'s
  registry/flag fixture hygiene (the `:npc_session_flags` on_exit cleanup).
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Npc.Touch
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.Handlers.MapLoadHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.TouchHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"
  @char_id 9001
  @other_char_id 9002

  defmodule TouchNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 60, y: 50, sprite: 58, name: "Toucher", trigger: {1, 1}}]

    @impl true
    def on_talk(ctx) do
      send(:on_touch_probe, {:talked, __MODULE__})
      ctx
    end

    @impl true
    def on_event("OnTouch", ctx) do
      send(:on_touch_probe, {:touched, __MODULE__})
      ctx
    end
  end

  defmodule WarperNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 70, y: 50, sprite: 45, name: "Warper", trigger: {0, 0}}]

    @impl true
    def on_talk(ctx) do
      send(:on_touch_probe, {:talked, __MODULE__})
      ctx
    end
  end

  defmodule OverlapNpcA do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 80, y: 50, sprite: 58, name: "OverlapA", trigger: {2, 0}}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTouch", ctx) do
      send(:on_touch_probe, {:touched, __MODULE__})
      ctx
    end
  end

  defmodule OverlapNpcB do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 82, y: 50, sprite: 58, name: "OverlapB", trigger: {2, 0}}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTouch", ctx) do
      send(:on_touch_probe, {:touched, __MODULE__})
      ctx
    end
  end

  defmodule OnceNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 90, y: 50, sprite: 58, name: "Once", trigger: {1, 1}}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTouch_", ctx) do
      send(:on_touch_probe, {:touched_once, ctx.char_id})
      ctx
    end
  end

  @npcs [TouchNpc, WarperNpc, OverlapNpcA, OverlapNpcB, OnceNpc]

  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Aesir.TestProbe.register!(:on_touch_probe)
    NpcRegistry.reload(@npcs)

    gids = Enum.map(@npcs, &gid_for/1)

    on_exit(fn ->
      :persistent_term.erase(NpcRegistry)
      Enum.each(gids, &:ets.delete(:npc_session_flags, &1))
      Enum.each(gids, &:ets.delete(Touch.table(), &1))
    end)

    stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
    stub(SpatialIndex, :get_units_in_range, fn _, _, _, _, _ -> [] end)
    stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)
    stub(Broadcast, :to_players, fn _, _, _ -> :ok end)
    stub(Warps, :for_map, fn _ -> :error end)

    :ok
  end

  describe "entering, staying, leaving and re-entering a trigger area" do
    test "fires once on entry, not while staying inside, again on re-entry" do
      gid = gid_for(TouchNpc)

      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:x, 57)
        |> Map.put(:y, 50)
        |> Map.put(:walk_path, [{58, 50}, {59, 50}, {60, 50}, {61, 50}, {62, 50}, {61, 50}])
        |> Map.put(:movement_state, :moving)

      register_player(game_state)

      state = %{game_state: game_state, connection_pid: self(), interaction_lock: nil}

      # (58, 50): still outside the [59..61, 49..51] rect.
      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      refute_receive {:touched, TouchNpc}, 50
      refute MapSet.member?(state.game_state.inside_npc_areas, gid)

      # (59, 50): enters the rect -> fires.
      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      assert_receive {:touched, TouchNpc}
      assert MapSet.member?(state.game_state.inside_npc_areas, gid)
      assert {_pid, ref, ^gid} = state.interaction_lock

      # The (dialog-less) interaction finishes immediately; clear the lock
      # exactly like the real session's :DOWN handler does.
      assert_receive {:DOWN, ^ref, :process, pid, reason}
      {:noreply, state} = PlayerSession.handle_info({:DOWN, ref, :process, pid, reason}, state)
      assert state.interaction_lock == nil

      # (60, 50) and (61, 50): still inside -> no re-fire.
      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      refute_receive {:touched, TouchNpc}, 50

      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      refute_receive {:touched, TouchNpc}, 50

      # (62, 50): leaves the rect -> cleared.
      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      refute MapSet.member?(state.game_state.inside_npc_areas, gid)

      # (61, 50): re-enters -> fires again.
      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      assert_receive {:touched, TouchNpc}
      assert MapSet.member?(state.game_state.inside_npc_areas, gid)
    end
  end

  describe "trigger area with no OnTouch label" do
    test "falls back to on_talk/1 (rAthena warper behavior)" do
      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:x, 69)
        |> Map.put(:y, 50)
        |> Map.put(:walk_path, [{70, 50}])
        |> Map.put(:movement_state, :moving)

      register_player(game_state)

      state = %{game_state: game_state, connection_pid: self(), interaction_lock: nil}

      {:noreply, ticked_state} = MovementHandler.handle_movement_tick(state)

      assert_receive {:talked, WarperNpc}
      gid = gid_for(WarperNpc)
      assert {_pid, _ref, ^gid} = ticked_state.interaction_lock
    end
  end

  describe "busy player" do
    test "skips the fire but still marks the area entered" do
      gid = gid_for(TouchNpc)
      fake_lock = {self(), make_ref(), 999}

      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:x, 57)
        |> Map.put(:y, 50)
        |> Map.put(:walk_path, [{58, 50}, {59, 50}])
        |> Map.put(:movement_state, :moving)

      register_player(game_state)

      state = %{game_state: game_state, connection_pid: self(), interaction_lock: fake_lock}

      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      {:noreply, state} = MovementHandler.handle_movement_tick(state)

      refute_receive {:touched, TouchNpc}, 100
      assert MapSet.member?(state.game_state.inside_npc_areas, gid)
      assert state.interaction_lock == fake_lock
    end

    test "pending skill text allows movement but suppresses OnTouch and remains pending" do
      gid = gid_for(TouchNpc)
      timer_ref = Process.send_after(self(), :unused_timeout, 60_000)

      pending = %SessionState.PendingSkillTextInput{
        request_id: 42,
        skill_id: 166,
        level: 1,
        target: {:ground, 59, 50},
        timer_ref: timer_ref
      }

      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:x, 57)
        |> Map.put(:y, 50)
        |> Map.put(:walk_path, [{58, 50}, {59, 50}])
        |> Map.put(:movement_state, :moving)

      register_player(game_state)

      state = %SessionState{
        game_state: game_state,
        connection_pid: self(),
        pending_skill_text_input: pending
      }

      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      {:noreply, state} = MovementHandler.handle_movement_tick(state)

      assert state.game_state.x == 59
      assert state.pending_skill_text_input == pending
      assert is_integer(Process.read_timer(timer_ref))
      assert MapSet.member?(state.game_state.inside_npc_areas, gid)
      assert state.interaction_lock == nil
      refute_receive {:touched, TouchNpc}, 100
    end
  end

  describe "disabled NPC" do
    test "never fires and is never marked entered" do
      gid = gid_for(TouchNpc)
      NpcSession.set_enabled(gid, false)

      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:x, 57)
        |> Map.put(:y, 50)
        |> Map.put(:walk_path, [{58, 50}, {59, 50}])
        |> Map.put(:movement_state, :moving)

      register_player(game_state)

      state = %{game_state: game_state, connection_pid: self(), interaction_lock: nil}

      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      {:noreply, state} = MovementHandler.handle_movement_tick(state)

      refute_receive {:touched, TouchNpc}, 100
      refute MapSet.member?(state.game_state.inside_npc_areas, gid)
      assert state.interaction_lock == nil
    end
  end

  describe "a cell that is both a warp trigger and a touch rect" do
    test "the warp wins; no touch fires and the area is not marked entered" do
      gid = gid_for(TouchNpc)

      warp =
        struct!(Warp,
          id: "test_warp_60_50",
          map: @map,
          to_map: "izlude",
          x: 60,
          y: 50,
          xs: 0,
          ys: 0,
          to_x: 150,
          to_y: 190,
          sprite: 45,
          name: "Izlude"
        )

      stub(Warps, :for_map, fn
        @map -> {:ok, [warp]}
        _ -> :error
      end)

      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:x, 59)
        |> Map.put(:y, 50)
        |> Map.put(:walk_path, [{60, 50}])
        |> Map.put(:movement_state, :moving)

      register_player(game_state)

      state = %{game_state: game_state, connection_pid: self(), interaction_lock: nil}

      {:noreply, ticked_state} = MovementHandler.handle_movement_tick(state)

      assert_received {:"$gen_cast", {:movement, {:warp, "izlude", 150, 190}}}
      refute_receive {:touched, TouchNpc}, 50
      refute_receive {:talked, TouchNpc}, 50
      refute MapSet.member?(ticked_state.game_state.inside_npc_areas, gid)
    end
  end

  describe "overlapping trigger rects" do
    test "both placements are entered once each; staying in the overlap fires nothing new" do
      gid_a = gid_for(OverlapNpcA)
      gid_b = gid_for(OverlapNpcB)

      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:x, 77)
        |> Map.put(:y, 50)
        |> Map.put(:walk_path, [{78, 50}, {79, 50}, {80, 50}, {81, 50}, {82, 50}])
        |> Map.put(:movement_state, :moving)

      register_player(game_state)

      state = %{game_state: game_state, connection_pid: self(), interaction_lock: nil}

      # (78, 50): enters A's rect [78..82] only -> fires A.
      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      assert_receive {:touched, OverlapNpcA}
      refute_receive {:touched, OverlapNpcB}, 50
      assert MapSet.member?(state.game_state.inside_npc_areas, gid_a)
      refute MapSet.member?(state.game_state.inside_npc_areas, gid_b)
      assert {_pid, ref_a, ^gid_a} = state.interaction_lock

      # The (dialog-less) interaction finishes immediately; clear the lock
      # like the real session's :DOWN handler does, so B's own entry below
      # isn't busy-skipped by A's already-finished interaction.
      assert_receive {:DOWN, ^ref_a, :process, pid_a, reason_a}

      {:noreply, state} =
        PlayerSession.handle_info({:DOWN, ref_a, :process, pid_a, reason_a}, state)

      assert state.interaction_lock == nil

      # (79, 50): still only inside A -> no new fire.
      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      refute_receive {:touched, OverlapNpcA}, 50
      refute_receive {:touched, OverlapNpcB}, 50

      # (80, 50): now also inside B's rect [80..84] -> fires B only.
      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      assert_receive {:touched, OverlapNpcB}
      refute_receive {:touched, OverlapNpcA}, 50
      assert MapSet.member?(state.game_state.inside_npc_areas, gid_a)
      assert MapSet.member?(state.game_state.inside_npc_areas, gid_b)

      # (81, 50) and (82, 50): still inside the overlap of both -> nothing new.
      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      refute_receive {:touched, OverlapNpcA}, 50
      refute_receive {:touched, OverlapNpcB}, 50

      {:noreply, _state} = MovementHandler.handle_movement_tick(state)
      refute_receive {:touched, OverlapNpcA}, 50
      refute_receive {:touched, OverlapNpcB}, 50
    end
  end

  describe "OnTouch_ and concealment" do
    test "a concealed player skips OnTouch_ without marking it, and OnTouch still fires" do
      gid = gid_for(OnceNpc)
      conceal(@char_id)

      state = walking_state(87, 50, [{88, 50}, {89, 50}])
      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      {:noreply, state} = MovementHandler.handle_movement_tick(state)

      refute_receive {:touched_once, _}, 50
      refute MapSet.member?(state.game_state.inside_npc_areas, gid)
      assert Touch.toucher(gid) == nil

      state = walking_state(58, 50, [{59, 50}])
      {:noreply, state} = MovementHandler.handle_movement_tick(state)

      assert_receive {:touched, TouchNpc}
      assert MapSet.member?(state.game_state.inside_npc_areas, gid_for(TouchNpc))
    end

    test "the concealing status ending re-runs the scan and fires the skipped OnTouch_" do
      gid = gid_for(OnceNpc)
      conceal(@char_id)

      state = walking_state(88, 50, [{89, 50}])
      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      refute_receive {:touched_once, _}, 50

      reveal(@char_id)
      {:noreply, state} = MovementHandler.recheck_touch(state, {@map, 89, 50})

      assert_receive {:touched_once, @char_id}
      assert MapSet.member?(state.game_state.inside_npc_areas, gid)
      assert Touch.toucher(gid) == @char_id
      assert {_pid, _ref, ^gid} = state.interaction_lock
    end

    test "a dead player triggers nothing" do
      state = walking_state(89, 50, [])
      dead = %{state | game_state: %{state.game_state | action_state: :dead}}

      assert TouchHandler.scan(dead) == dead
      refute_receive {:touched_once, _}, 50
      assert Touch.toucher(gid_for(OnceNpc)) == nil
    end
  end

  describe "one toucher at a time" do
    test "a second player is skipped unmarked, and gets the claim when the first leaves" do
      gid = gid_for(OnceNpc)

      first = walking_state(88, 50, [{89, 50}, {90, 50}, {91, 50}, {92, 50}])
      {:noreply, first} = MovementHandler.handle_movement_tick(first)
      assert_receive {:touched_once, @char_id}
      assert Touch.toucher(gid) == @char_id
      first = clear_lock(first)

      second = walking_state(88, 51, [{89, 51}], @other_char_id)
      {:noreply, second} = MovementHandler.handle_movement_tick(second)
      refute_receive {:touched_once, _}, 50
      refute MapSet.member?(second.game_state.inside_npc_areas, gid)
      assert Touch.toucher(gid) == @char_id

      # Still inside: the claim stays with the first player.
      {:noreply, first} = MovementHandler.handle_movement_tick(first)
      {:noreply, first} = MovementHandler.handle_movement_tick(first)
      assert Touch.toucher(gid) == @char_id

      # (92, 50) leaves the [89..91] rect: the claim is released and offered
      # to the second player, whose session validates and takes it.
      {:noreply, first} = MovementHandler.handle_movement_tick(first)
      refute MapSet.member?(first.game_state.inside_npc_areas, gid)
      assert Touch.toucher(gid) == nil
      assert_receive {:"$gen_cast", {:npc, {:touch_handoff, ^gid, excluded}}}
      assert MapSet.member?(excluded, @char_id)

      second = TouchHandler.handle_handoff(second, gid, excluded)
      assert_receive {:touched_once, @other_char_id}
      assert Touch.toucher(gid) == @other_char_id
      assert MapSet.member?(second.game_state.inside_npc_areas, gid)
    end

    test "a handoff to a player that left the area moves on without claiming" do
      gid = gid_for(OnceNpc)
      outside = walking_state(80, 60, [], @other_char_id)

      assert TouchHandler.handle_handoff(outside, gid, MapSet.new([@char_id])) == outside
      refute_receive {:touched_once, _}, 50
      assert Touch.toucher(gid) == nil
    end

    test "a warp hands off every claim the player holds" do
      gid = gid_for(OnceNpc)
      state = walking_state(88, 50, [{89, 50}])
      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      assert Touch.toucher(gid) == @char_id

      _second = walking_state(90, 51, [], @other_char_id)
      TouchHandler.leave_all(state.game_state)

      assert Touch.toucher(gid) == nil
      assert_receive {:"$gen_cast", {:npc, {:touch_handoff, ^gid, _excluded}}}
    end
  end

  describe "other scan triggers" do
    test "a knockback landing inside a trigger area fires it" do
      gid = gid_for(TouchNpc)
      state = walking_state(57, 50, [])

      {:noreply, state} = MovementHandler.handle_displacement(state, 57, 50, @map, 59, 50)

      assert_receive {:touched, TouchNpc}
      assert MapSet.member?(state.game_state.inside_npc_areas, gid)
    end

    test "the map-load ack scans the spawn cell when no warp is underfoot" do
      Mimic.copy(SkillUnitManager)
      stub(SkillUnitManager, :snapshot_for, fn _id, _map, _x, _y, _range -> MapSet.new() end)
      gid = gid_for(TouchNpc)

      game_state = %{walking_state(60, 50, []).game_state | pending_map_load: :warp}
      state = %SessionState{game_state: game_state, connection_pid: self()}

      {:noreply, loaded} = MapLoadHandler.handle_map_loaded(state)

      assert_receive {:touched, TouchNpc}
      assert MapSet.member?(loaded.game_state.inside_npc_areas, gid)
    end
  end

  describe "event queue" do
    test "a touch while busy is queued and runs once the dialog ends" do
      gid = gid_for(TouchNpc)
      {lock_pid, lock_ref} = fake_dialog()

      state = %{walking_state(58, 50, [{59, 50}]) | interaction_lock: {lock_pid, lock_ref, 999}}
      {:noreply, state} = MovementHandler.handle_movement_tick(state)

      refute_receive {:touched, TouchNpc}, 50
      assert state.npc_event_queue == [{gid, "OnTouch"}]
      assert MapSet.member?(state.game_state.inside_npc_areas, gid)

      Process.exit(lock_pid, :kill)
      assert_receive {:DOWN, ^lock_ref, :process, ^lock_pid, reason}

      {:noreply, state} =
        PlayerSession.handle_info({:DOWN, lock_ref, :process, lock_pid, reason}, state)

      assert state.interaction_lock == nil
      assert state.npc_event_queue == []
      refute_receive {:touched, TouchNpc}, 50

      assert_receive {:npc, {:run_queued_event, ^gid, "OnTouch"}} = message, 500
      {:noreply, state} = PlayerSession.handle_info(message, state)

      assert_receive {:touched, TouchNpc}
      assert {_pid, _ref, ^gid} = state.interaction_lock
    end

    test "a queued touch is dropped when the player has left the area" do
      gid = gid_for(TouchNpc)
      {lock_pid, lock_ref} = fake_dialog()

      state = %{walking_state(58, 50, [{59, 50}]) | interaction_lock: {lock_pid, lock_ref, 999}}
      {:noreply, state} = MovementHandler.handle_movement_tick(state)
      assert state.npc_event_queue == [{gid, "OnTouch"}]

      moved = %{state | game_state: %{state.game_state | x: 70, y: 60}}
      Process.exit(lock_pid, :kill)
      assert_receive {:DOWN, ^lock_ref, :process, ^lock_pid, reason}

      {:noreply, moved} =
        PlayerSession.handle_info({:DOWN, lock_ref, :process, lock_pid, reason}, moved)

      assert_receive {:npc, {:run_queued_event, ^gid, "OnTouch"}} = message, 500
      {:noreply, moved} = PlayerSession.handle_info(message, moved)

      refute_receive {:touched, TouchNpc}, 50
      assert moved.interaction_lock == nil
      assert moved.npc_event_queue == []
    end

    @tag :capture_log
    test "a third queued event is dropped, the claim and the area still taken" do
      gid = gid_for(OnceNpc)
      {lock_pid, lock_ref} = fake_dialog()

      state =
        walking_state(90, 50, [])
        |> Map.put(:npc_event_queue, [{1, "OnA"}, {2, "OnB"}])
        |> Map.put(:interaction_lock, {lock_pid, lock_ref, 999})

      queued = TouchHandler.handle_handoff(state, gid, MapSet.new())

      assert queued.npc_event_queue == [{1, "OnA"}, {2, "OnB"}]
      assert Touch.toucher(gid) == @char_id
      assert MapSet.member?(queued.game_state.inside_npc_areas, gid)
      Process.exit(lock_pid, :kill)
    end
  end

  describe "warp/map change" do
    test "clears inside_npc_areas" do
      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:inside_npc_areas, MapSet.new([1, 2, 3]))

      relocated = PlayerState.relocate(game_state, "izlude", 10, 10)

      assert relocated.inside_npc_areas == MapSet.new()
    end
  end

  defp gid_for(module) do
    {^module, placement} = Enum.find(NpcRegistry.entries(), fn {mod, _} -> mod == module end)
    NpcRegistry.entity_id(placement)
  end

  # A registered, on-map player at `{x, y}` about to walk `path`; the test
  # process stands in for its session and connection.
  defp walking_state(x, y, path, char_id \\ @char_id) do
    game_state =
      char_id
      |> character()
      |> PlayerState.new()
      |> Map.merge(%{x: x, y: y, walk_path: path, pending_map_load: nil})
      |> Map.put(:movement_state, if(path == [], do: :standing, else: :moving))

    register_player(game_state, char_id)
    %{game_state: game_state, connection_pid: self(), interaction_lock: nil}
  end

  # Clears a finished dialog-less interaction's lock like the session's :DOWN
  # handler does.
  defp clear_lock(%{interaction_lock: {_pid, ref, _gid}} = state) do
    assert_receive {:DOWN, ^ref, :process, pid, reason}
    {:noreply, state} = PlayerSession.handle_info({:DOWN, ref, :process, pid, reason}, state)
    state
  end

  defp fake_dialog do
    pid = spawn(fn -> Process.sleep(:infinity) end)
    {pid, Process.monitor(pid)}
  end

  defp conceal(char_id) do
    stub(StatusDisplay, :spawn_state, fn
      :player, ^char_id ->
        %{body_state: 0, health_state: 0, effect_state: Option.id(:hide), virtue: 0}

      _type, _id ->
        %{body_state: 0, health_state: 0, effect_state: 0, virtue: 0}
    end)
  end

  defp reveal(_char_id) do
    stub(StatusDisplay, :spawn_state, fn _type, _id ->
      %{body_state: 0, health_state: 0, effect_state: 0, virtue: 0}
    end)
  end

  defp register_player(game_state, char_id \\ @char_id) do
    UnitRegistry.register_unit(:player, char_id, PlayerState, game_state, self())
    SpatialIndex.add_unit(:player, char_id, game_state.x, game_state.y, @map)
    Movement.drain_dirty(@map)
  end

  defp character(id \\ @char_id) do
    %Character{
      id: id,
      account_id: 100,
      name: "Wanderer",
      last_map: @map,
      last_x: 50,
      last_y: 50,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }
  end
end
