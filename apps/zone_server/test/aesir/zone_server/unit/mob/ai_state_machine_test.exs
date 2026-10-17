defmodule Aesir.ZoneServer.Unit.Mob.AIStateMachineTest do
  @moduledoc """
  Verifies the hard AI think: the move gate, random walks and their timing,
  the skill state each step sets, the aggressive mode, target search and
  validity, the attacked event's target change, the chase destination and the
  immobile fallback.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Guild.Relations
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!

  # Mob combatants read their live statuses (`MobState.to_combatant/1`); a private
  # seeded status table keeps another async test's status on the same mob
  # instance id from leaking into this file.
  setup :setup_ets_tables

  setup do
    Mimic.copy(Interpreter)
    Mimic.copy(StatusStorage)
    Mimic.copy(Combat)
    Mimic.copy(SpatialIndex)
    Mimic.copy(MapCache)
    Mimic.copy(Cell)
    Mimic.copy(UnitRegistry)

    stub(Interpreter, :can_move?, fn _type, _id -> true end)
    stub(Interpreter, :can_attack?, fn _type, _id -> true end)
    stub(Interpreter, :targetable?, fn _type, _id -> true end)
    stub(Interpreter, :charmed_against?, fn _type, _id, _target_id -> false end)
    stub(StatusStorage, :has_status?, fn _type, _id, _status -> false end)
    stub(MapCache, :get, fn _map -> {:ok, :map_data} end)
    stub(Cell, :traversable?, fn "prontera", _x, _y -> true end)
    stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _range -> [] end)
    stub(SpatialIndex, :units_in_area, fn _map, _x1, _y1, _x2, _y2 -> [] end)
    stub_paths(fn from, to -> {:ok, line_path(from, to)} end)
    stub(Combat, :execute_mob_attack, fn _state, _target -> :ok end)

    stub(UnitRegistry, :get_unit, fn :player, _id ->
      {:ok, {PlayerState, living_player_state(), nil}}
    end)

    :ok
  end

  describe "can_move?/2" do
    test "needs the move mode, no movement-blocking status and no walk delay" do
      mono = System.monotonic_time(:millisecond)

      assert AIStateMachine.can_move?(movable_mob_state(), mono)
      refute AIStateMachine.can_move?(base_mob_state(), mono)

      stub(Interpreter, :can_move?, fn :mob, 1 -> false end)
      refute AIStateMachine.can_move?(movable_mob_state(), mono)
      stub(Interpreter, :can_move?, fn :mob, 1 -> true end)

      delayed = %{movable_mob_state() | walk_delay_until: mono + 500}
      refute AIStateMachine.can_move?(delayed, mono)
      assert AIStateMachine.can_move?(delayed, mono + 500)
    end
  end

  describe "random walk" do
    test "a due walk starts in the walk state and books the next one past the walk" do
      now = 10_000
      state = %{movable_mob_state() | next_walktime: now}

      {:ok, walked} = AIStateMachine.random_walk(state, now, System.monotonic_time(:millisecond))

      assert walked.skill_state == :walk
      assert walked.movement_state == :moving
      assert walked.walk_path != []
      {dx, dy} = List.last(walked.walk_path)
      assert {dx, dy} != {100, 100}
      assert max(abs(dx - 100), abs(dy - 100)) <= 7
      assert walked.next_walktime >= now + 4000 + walk_time(walked)
      assert walked.next_walktime <= now + 4999 + walk_time(walked)
    end

    test "no walk before its time, without the move mode, barred from random walks or blocked" do
      now = 10_000
      mono = System.monotonic_time(:millisecond)

      assert {:error, _} =
               AIStateMachine.random_walk(
                 %{movable_mob_state() | next_walktime: now + 1},
                 now,
                 mono
               )

      assert {:error, _} =
               AIStateMachine.random_walk(%{base_mob_state() | next_walktime: now}, now, mono)

      barred = %{movable_mob_state(modes: [:can_move, :no_random_walk]) | next_walktime: now}
      assert {:error, _} = AIStateMachine.random_walk(barred, now, mono)

      stub(Interpreter, :can_move?, fn :mob, 1 -> false end)

      assert {:error, _} =
               AIStateMachine.random_walk(%{movable_mob_state() | next_walktime: now}, now, mono)
    end

    test "every candidate cell being impassable fails the walk" do
      stub(Cell, :traversable?, fn "prontera", _x, _y -> false end)
      now = 10_000

      assert {:error, state} =
               AIStateMachine.random_walk(%{movable_mob_state() | next_walktime: now}, now, 0)

      assert state.movement_state == :standing
    end

    test "the think walks an idle mob with no target when the walk is due, slaves never" do
      now = System.system_time(:millisecond)

      walked = think(%{movable_mob_state() | next_walktime: now}, now)
      assert walked.skill_state == :walk

      later = think(%{movable_mob_state() | next_walktime: now + 1}, now)
      assert later.skill_state == :idle
      assert later.movement_state == :standing

      slave = think(%{movable_mob_state() | next_walktime: now, master_id: 7}, now)
      assert slave.movement_state == :standing
    end

    test "a failed walk is retried within a second, or once the walk delay ends" do
      stub(Cell, :traversable?, fn "prontera", _x, _y -> false end)
      now = System.system_time(:millisecond)

      retried = think(%{movable_mob_state() | next_walktime: now}, now)
      assert retried.next_walktime >= now and retried.next_walktime < now + 1000

      mono = System.monotonic_time(:millisecond)
      delayed = %{movable_mob_state() | next_walktime: now, walk_delay_until: mono + 3000}
      waited = think(delayed, now)
      assert_in_delta waited.next_walktime, now + 3000, 50

      past = %{movable_mob_state() | next_walktime: now - 500, walk_delay_until: mono - 100}
      booked = think(past, now)
      assert_in_delta booked.next_walktime, now - 100, 50
    end
  end

  describe "unlock_target/2" do
    test "an attack or chase state stops the attack, goes idle and books a walk in 4-5 s" do
      now = 10_000

      for skill_state <- [:berserk, :angry, :rush, :follow] do
        state = %{combat_mob_state() | skill_state: skill_state, chase_target: {:player, 2}}
        result = AIStateMachine.unlock_target(state, now)

        assert {result.skill_state, result.target_ref, result.attack_target, result.chase_target} ==
                 {:idle, nil, nil, nil}

        assert result.next_walktime in (now + 4000)..(now + 4999)
      end
    end

    test "idle and an ongoing walk keep their state and walk time; a finished walk goes idle" do
      idle = %{base_mob_state() | next_walktime: 5, target_ref: {:player, 2}}

      assert %{skill_state: :idle, next_walktime: 5, target_ref: nil} =
               AIStateMachine.unlock_target(idle, 10_000)

      walking = %{
        base_mob_state()
        | skill_state: :walk,
          movement_state: :moving,
          next_walktime: 5
      }

      assert %{skill_state: :walk, next_walktime: 5} =
               AIStateMachine.unlock_target(walking, 10_000)

      stopped = %{walking | movement_state: :standing}

      assert %{skill_state: :idle, next_walktime: 5} =
               AIStateMachine.unlock_target(stopped, 10_000)
    end
  end

  describe "skill states set by the think" do
    setup do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 -> [] end)
      :ok
    end

    test "an attack order enters berserk, or angry for an aggressive mob" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {100, 100, "prontera"}} end)

      assert think(combat_mob_state()).skill_state == :berserk
      assert think(%{combat_mob_state() | aggressive: true}).skill_state == :angry
    end

    test "a refused swing still enters the attack state" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {100, 100, "prontera"}} end)
      stub(Combat, :execute_mob_attack, fn _state, _target -> {:error, :invalid_target} end)

      result = think(%{combat_mob_state() | skill_state: :idle})

      assert {result.skill_state, result.attack_target} == {:berserk, {:player, 2}}
      assert result.last_attack_time == nil
    end

    test "a hidden mob in range enters the attack state without swinging" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {100, 100, "prontera"}} end)

      stub(StatusStorage, :has_status?, fn type, _id, status ->
        type == :mob and status == :sc_hiding
      end)

      reject(&Combat.execute_mob_attack/2)

      result = think(%{combat_mob_state() | skill_state: :idle})

      assert {result.skill_state, result.attack_target} == {:berserk, nil}
    end

    test "a chase walk enters rush, or follow for an aggressive mob" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {105, 105, "prontera"}} end)

      assert think(chase_mob_state()).skill_state == :rush
      assert think(%{chase_mob_state() | aggressive: true}).skill_state == :follow
    end

    test "an attacked aggressive mob leaves its angry states on its next state change" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {105, 105, "prontera"}} end)
      angry = %{chase_mob_state(modes: [:can_move, :can_attack, :angry]) | skill_state: :angry}

      assert think(angry).skill_state == :follow
      assert think(MobState.set_attacked(angry, {:player, 2}, false)).skill_state == :rush
    end

    test "a chasing mob already walking keeps walking" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {105, 105, "prontera"}} end)

      walking = %{
        chase_mob_state()
        | movement_state: :moving,
          walk_path: [{101, 101}],
          aggressive: true
      }

      result = think(walking)

      assert {result.skill_state, result.movement_state, result.walk_path} ==
               {:rush, :moving, [{101, 101}]}
    end

    test "an angry mob chases only a reachable target" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {105, 105, "prontera"}} end)
      stub_paths(fn _from, _to -> {:error, :no_path} end)

      result = think(%{chase_mob_state() | skill_state: :angry})

      assert {result.skill_state, result.target_ref} == {:idle, nil}
    end
  end

  describe "lock_target/3" do
    setup do
      stub(SpatialIndex, :get_unit_position, fn
        :player, 2 -> {:ok, {101, 100, "prontera"}}
        :player, 3 -> {:ok, {100, 101, "prontera"}}
      end)

      :ok
    end

    test "a taunt takes a target the mob may change to, and an unattackable unit is not taken" do
      assert AIStateMachine.lock_target(base_mob_state(), {:player, 2}, false).target_ref ==
               {:player, 2}

      kept = AIStateMachine.lock_target(combat_mob_state(), {:player, 3}, false)
      assert kept.target_ref == {:player, 2}

      stub(Interpreter, :targetable?, fn :player, 3 -> false end)
      assert AIStateMachine.lock_target(base_mob_state(), {:player, 3}, false).target_ref == nil
    end

    test "a provoke stamps the provoker and takes an aggressive mob out of its mode" do
      angry = %{base_mob_state(modes: [:angry]) | aggressive: true}

      provoked = AIStateMachine.lock_target(angry, {:player, 2}, true)

      assert {provoked.target_ref, provoked.provoke_flag, provoked.aggressive} ==
               {{:player, 2}, {:player, 2}, false}

      other = AIStateMachine.lock_target(%{provoked | aggressive: true}, {:player, 3}, false)
      assert {other.target_ref, other.provoke_flag, other.aggressive} == {{:player, 3}, nil, true}
    end
  end

  describe "immobile mob with a target out of range" do
    setup do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 -> [] end)
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {105, 105, "prontera"}} end)
      :ok
    end

    test "without the move mode it goes idle and keeps its target for 2 s, then unlocks it" do
      now = System.system_time(:millisecond)

      state = %{
        combat_mob_state(modes: [:can_attack])
        | skill_state: :rush,
          last_canmove: now - 1000
      }

      kept = think(state, now)
      assert {kept.skill_state, kept.target_ref} == {:idle, {:player, 2}}

      unlocked = think(%{state | last_canmove: now - 2001}, now)
      assert {unlocked.skill_state, unlocked.target_ref} == {:idle, nil}
    end

    test "an attacking mob keeps its state while held" do
      now = System.system_time(:millisecond)

      state = %{
        combat_mob_state(modes: [:can_attack])
        | attack_target: {:player, 2},
          attack_timer_at: now + 500,
          last_canmove: now - 5000
      }

      assert think(state, now) == state
    end

    test "a movement-blocking status holds a mob that can move" do
      stub(Interpreter, :can_move?, fn :mob, 1 -> false end)
      now = System.system_time(:millisecond)

      held = think(%{chase_mob_state() | last_canmove: now}, now)

      assert {held.skill_state, held.target_ref, held.movement_state} ==
               {:idle, {:player, 2}, :standing}
    end

    test "a walk-delayed mob keeps the chase target and starts the walk once the delay ends" do
      now = System.system_time(:millisecond)
      mono = System.monotonic_time(:millisecond)
      delayed = %{chase_mob_state() | walk_delay_until: mono + 60_000}

      waiting = think(delayed, now)

      assert {waiting.skill_state, waiting.chase_target, waiting.movement_state} ==
               {:rush, {:player, 2}, :standing}

      walking = think(%{waiting | walk_delay_until: 0}, now)
      assert {walking.skill_state, walking.movement_state} == {:rush, :moving}
    end

    test "the think stamps the last time the mob could move" do
      now = System.system_time(:millisecond)

      assert think(chase_mob_state(), now).last_canmove == now
      assert think(base_mob_state(), now).last_canmove == nil
    end
  end

  describe "attack status gating" do
    test "a no_attack mob does not attack and last_attack_time is unchanged" do
      test_pid = self()
      stub(Interpreter, :can_attack?, fn :mob, 1 -> false end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Combat, :execute_mob_attack, fn _state, _target ->
        send(test_pid, :attacked)
        :ok
      end)

      state = combat_mob_state()

      result = think(state)

      refute_received :attacked
      assert result.last_attack_time == state.last_attack_time
    end

    test "an unafflicted mob attacks and updates last_attack_time" do
      test_pid = self()

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Combat, :execute_mob_attack, fn _state, _target ->
        send(test_pid, :attacked)
        :ok
      end)

      state = combat_mob_state()

      result = think(state)

      assert_received :attacked
      assert result.last_attack_time != nil
    end

    test "a landed swing rests the AI for the mob's attack motion" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {100, 100, "prontera"}} end)
      stub(Combat, :execute_mob_attack, fn _state, _target -> :ok end)
      state = combat_mob_state()

      result = think(state)

      assert result.next_think_at == result.last_attack_time + MobState.get_attack_motion(state)
    end
  end

  describe "target search filter" do
    test "an untargetable (trick-dead) player is not acquired by an idle aggressive mob" do
      stub(Interpreter, :targetable?, fn :player, 2 -> false end)

      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      state = aggressive_idle_mob_state()

      result = think(state)

      assert result.target_ref == nil
      assert result.skill_state == :idle
    end

    test "a corpse is not acquired by an idle aggressive mob" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, corpse_player_state(), nil}}
      end)

      result = think(aggressive_idle_mob_state())

      assert result.target_ref == nil
      assert result.skill_state == :idle
    end

    test "a player missing its authoritative snapshot is not acquired" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 -> {:error, :not_found} end)

      result = think(aggressive_idle_mob_state())

      assert result.target_ref == nil
      assert result.skill_state == :idle
    end

    test "a player in Gangster Paradise is not acquired by an idle aggressive mob" do
      stub(StatusStorage, :has_status?, fn type, _id, status ->
        type == :player and status == :sc_gangsterparadise
      end)

      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      result = think(aggressive_idle_mob_state())

      assert result.target_ref == nil
      assert result.skill_state == :idle
    end

    test "an invincible player is not acquired by an idle aggressive mob" do
      stub(Invincibility, :active?, fn _unit -> true end)

      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      result = think(aggressive_idle_mob_state())

      assert result.target_ref == nil
      assert result.skill_state == :idle
    end

    test "the search covers the square of the view range: a player on its corner is acquired" do
      state = aggressive_idle_mob_state()

      {x1, y1, x2, y2} =
        {100 - state.view_range, 100 - state.view_range, 100 + state.view_range,
         100 + state.view_range}

      stub(SpatialIndex, :units_in_area, fn "prontera", ^x1, ^y1, ^x2, ^y2 -> [{:player, 2}] end)
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {x2, y2, "prontera"}} end)

      assert think(state).target_ref == {:player, 2}
    end

    test "a targetable player is acquired by an idle aggressive mob" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      state = aggressive_idle_mob_state()

      result = think(state)

      assert result.target_ref == {:player, 2}
      assert result.skill_state == :berserk
    end

    test "an angry mob follows a target it finds out of attack range" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 -> [{:player, 2}] end)
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {105, 105, "prontera"}} end)

      result = think(aggressive_idle_mob_state(modes: [:aggressive, :angry, :can_move]))

      assert {result.target_ref, result.skill_state, result.aggressive} ==
               {{:player, 2}, :follow, true}
    end

    test "a target found in attack range takes an angry mob out of its aggressive mode" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 -> [{:player, 2}] end)
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {101, 101, "prontera"}} end)

      result = think(aggressive_idle_mob_state(modes: [:aggressive, :angry, :can_move]))

      assert {result.target_ref, result.skill_state, result.aggressive} ==
               {{:player, 2}, :berserk, false}
    end

    test "the closest candidate wins, and a current target is kept unless one is closer" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}, {:player, 3}]
      end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2 -> {:ok, {106, 100, "prontera"}}
        :player, 3 -> {:ok, {104, 100, "prontera"}}
      end)

      assert think(aggressive_idle_mob_state(modes: [:aggressive, :can_move])).target_ref ==
               {:player, 3}

      following = %{
        aggressive_idle_mob_state(modes: [:aggressive, :can_move])
        | skill_state: :follow,
          target_ref: {:player, 2},
          aggressive: true
      }

      assert think(following).target_ref == {:player, 3}

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2 -> {:ok, {104, 100, "prontera"}}
        :player, 3 -> {:ok, {106, 100, "prontera"}}
      end)

      assert think(following).target_ref == {:player, 2}
    end

    test "a target-weak mob skips candidates within five levels of it, out of sight or out of path" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 -> [{:player, 2}] end)
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {104, 100, "prontera"}} end)
      weak = aggressive_idle_mob_state(modes: [:aggressive, :target_weak, :can_move])

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, leveled_player(20), nil}}
      end)

      assert think(weak).target_ref == nil

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, leveled_player(19), nil}}
      end)

      assert think(weak).target_ref == {:player, 2}

      stub_paths(fn _from, _to -> {:ok, Enum.map(1..13, &{100 + &1, 100})} end)

      assert think(weak).target_ref == nil
    end

    test "a homunculus pick is never replaced by a player" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}, {:homunculus, 501}]
      end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2 -> {:ok, {101, 100, "prontera"}}
        :homunculus, 501 -> {:ok, {105, 100, "prontera"}}
      end)

      stub(UnitRegistry, :get_unit, fn
        :homunculus, 501 -> {:ok, {HomunculusState, homunculus_state(42), nil}}
        :player, 2 -> {:ok, {PlayerState, living_player_state(), nil}}
      end)

      following = %{
        aggressive_idle_mob_state(modes: [:aggressive, :can_move])
        | skill_state: :follow,
          target_ref: {:homunculus, 501},
          aggressive: true
      }

      assert think(following).target_ref == {:homunculus, 501}
    end

    test "a chasing mob with change_chase takes an enemy that is already in attack range" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 -> [{:player, 3}] end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2 -> {:ok, {106, 100, "prontera"}}
        :player, 3 -> {:ok, {101, 100, "prontera"}}
      end)

      chasing = chase_mob_state(modes: [:can_move, :can_attack, :change_chase])
      assert think(chasing).target_ref == {:player, 3}
      assert think(chase_mob_state()).target_ref == {:player, 2}

      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 3}, {:player, 4}]
      end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2 -> {:ok, {106, 100, "prontera"}}
        :player, 3 -> {:ok, {101, 100, "prontera"}}
        :player, 4 -> {:ok, {100, 101, "prontera"}}
      end)

      assert think(chasing).target_ref == {:player, 4}
    end
  end

  describe "owner-aware hostility in the aggro scan" do
    test "a mob does not acquire a living player from its own guild" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 7}, nil}}
      end)

      state = %MobState{aggressive_idle_mob_state() | guild_id: 7}

      result = think(state)

      assert result.target_ref == nil
      assert result.skill_state == :idle
    end

    test "a mob acquires a living player from a different guild" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 8}, nil}}
      end)

      state = %MobState{aggressive_idle_mob_state() | guild_id: 7}

      result = think(state)

      assert result.target_ref == {:player, 2}
      assert result.skill_state == :berserk
    end

    test "a mob does not acquire a living player from an allied guild" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 9}, nil}}
      end)

      stub(Relations, :friendly?, fn 7, 9 -> true end)

      state = %MobState{aggressive_idle_mob_state() | guild_id: 7}

      result = think(state)

      assert result.target_ref == nil
      assert result.skill_state == :idle
    end

    test "a mob still acquires a living player from an unrelated guild" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 8}, nil}}
      end)

      stub(Relations, :friendly?, fn 7, 8 -> false end)

      state = %MobState{aggressive_idle_mob_state() | guild_id: 7}

      result = think(state)

      assert result.target_ref == {:player, 2}
      assert result.skill_state == :berserk
    end

    test "a guildless mob still acquires a player belonging to a guild" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 7}, nil}}
      end)

      result = think(aggressive_idle_mob_state())

      assert result.target_ref == {:player, 2}
      assert result.skill_state == :berserk
    end

    test "a mob does not acquire a homunculus whose owner shares its guild" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:homunculus, 501}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :homunculus, 501 ->
          {:ok, {HomunculusState, homunculus_state(42), nil}}

        :player, 42 ->
          {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 7}, nil}}
      end)

      state = %MobState{aggressive_idle_mob_state() | guild_id: 7}

      result = think(state)

      assert result.target_ref == nil
      assert result.skill_state == :idle
    end

    test "a mob acquires a homunculus whose owner belongs to a different guild" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:homunculus, 501}]
      end)

      stub(SpatialIndex, :get_unit_position, fn :homunculus, 501 ->
        {:ok, {101, 101, "prontera"}}
      end)

      stub(UnitRegistry, :get_unit, fn
        :homunculus, 501 ->
          {:ok, {HomunculusState, homunculus_state(42), nil}}

        :player, 42 ->
          {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 8}, nil}}
      end)

      state = %MobState{aggressive_idle_mob_state() | guild_id: 7}

      result = think(state)

      assert result.target_ref == {:homunculus, 501}
      assert result.skill_state == :berserk
    end

    test "a guild-owned mob does not acquire a homunculus whose owner's guild is allied" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:homunculus, 501}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :homunculus, 501 ->
          {:ok, {HomunculusState, homunculus_state(42), nil}}

        :player, 42 ->
          {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 8}, nil}}
      end)

      stub(Relations, :friendly?, fn 7, 8 -> true end)

      state = %MobState{aggressive_idle_mob_state() | guild_id: 7}

      result = think(state)

      assert result.target_ref == nil
      assert result.skill_state == :idle
    end

    test "a guild-owned mob acquires a homunculus whose owner's guild is unrelated" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:homunculus, 501}]
      end)

      stub(SpatialIndex, :get_unit_position, fn :homunculus, 501 ->
        {:ok, {101, 101, "prontera"}}
      end)

      stub(UnitRegistry, :get_unit, fn
        :homunculus, 501 ->
          {:ok, {HomunculusState, homunculus_state(42), nil}}

        :player, 42 ->
          {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 8}, nil}}
      end)

      stub(Relations, :friendly?, fn 7, 8 -> false end)

      state = %MobState{aggressive_idle_mob_state() | guild_id: 7}

      result = think(state)

      assert result.target_ref == {:homunculus, 501}
      assert result.skill_state == :berserk
    end

    test "an ordinary mob acquiring a homunculus never resolves the owner's guild" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:homunculus, 501}]
      end)

      stub(SpatialIndex, :get_unit_position, fn :homunculus, 501 ->
        {:ok, {101, 101, "prontera"}}
      end)

      stub(UnitRegistry, :get_unit, fn
        :homunculus, 501 ->
          {:ok, {HomunculusState, homunculus_state(42), nil}}

        :player, _id ->
          flunk("an ordinary mob must not resolve the homunculus owner's guild")
      end)

      result = think(aggressive_idle_mob_state())

      assert result.target_ref == {:homunculus, 501}
      assert result.skill_state == :berserk
    end
  end

  describe "target search concealment filter" do
    test "a concealed player is not acquired by a normal mob" do
      :ok = StatusStorage.apply_status(:player, 2, :sc_cloaking)

      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      result = think(aggressive_idle_mob_state())

      assert result.target_ref == nil
      assert result.skill_state == :idle
    end

    test "a concealed player is acquired by a boss mob, which acts as a detector" do
      :ok = StatusStorage.apply_status(:player, 2, :sc_cloaking)

      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      base = base_mob_state(modes: [:aggressive, :detector, :status_immune, :knockback_immune])
      state = %MobState{base | x: 100, y: 100, skill_state: :idle, target_ref: nil}

      result = think(state)

      assert result.target_ref == {:player, 2}
      assert result.skill_state == :berserk
    end

    test "a concealed player is acquired by a non-boss detector mob" do
      :ok = StatusStorage.apply_status(:player, 2, :sc_cloaking)

      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      base = base_mob_state(modes: [:aggressive, :detector])
      state = %MobState{base | x: 100, y: 100, skill_state: :idle, target_ref: nil}

      result = think(state)

      assert result.target_ref == {:player, 2}
    end

    test "a player who un-conceals is acquirable again by a normal mob" do
      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 2}]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      :ok = StatusStorage.apply_status(:player, 2, :sc_hiding)

      concealed = think(aggressive_idle_mob_state())

      assert concealed.target_ref == nil

      :ok = StatusStorage.remove_status(:player, 2, :sc_hiding)

      revealed = think(aggressive_idle_mob_state())

      assert revealed.target_ref == {:player, 2}
      assert revealed.skill_state == :berserk
    end
  end

  describe "wink of charm targeting" do
    test "a charmed mob keeps its charmer as its target but never attacks it" do
      stub(Interpreter, :charmed_against?, fn :mob, 1, 2 -> true end)
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {100, 100, "prontera"}} end)
      reject(&Combat.execute_mob_attack/2)

      result = think(%{combat_mob_state() | skill_state: :idle})

      assert {result.target_ref, result.attack_target, result.skill_state} ==
               {{:player, 2}, nil, :idle}
    end

    test "a charmed mob's search finds its charmer like any other player" do
      stub(Interpreter, :charmed_against?, fn :mob, 1, target_id -> target_id == 2 end)

      stub(SpatialIndex, :units_in_area, fn "prontera", _x1, _y1, _x2, _y2 ->
        [{:player, 3}, {:player, 2}]
      end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2 -> {:ok, {101, 101, "prontera"}}
        :player, 3 -> {:ok, {103, 103, "prontera"}}
      end)

      reject(&Combat.execute_mob_attack/2)

      result = think(aggressive_idle_mob_state())

      assert result.target_ref == {:player, 2}
      assert result.attack_target == nil
    end

    test "a charmed mob attacks a different player normally" do
      test_pid = self()
      stub(Interpreter, :charmed_against?, fn :mob, 1, target_id -> target_id == 2 end)

      stub(SpatialIndex, :get_unit_position, fn :player, 3 ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Combat, :execute_mob_attack, fn _state, {:player, 3} ->
        send(test_pid, :attacked)
        :ok
      end)

      result =
        combat_mob_state()
        |> MobState.set_target(3)
        |> think()

      assert_received :attacked
      assert result.target_ref == {:player, 3}
    end
  end

  describe "concealment while already targeted" do
    test "a mob in combat drops a target that concealed itself" do
      test_pid = self()
      :ok = StatusStorage.apply_status(:player, 2, :sc_hiding)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Combat, :execute_mob_attack, fn _state, _target ->
        send(test_pid, :attacked)
        :ok
      end)

      result = think(combat_mob_state())

      assert result.target_ref == nil
      assert result.skill_state == :idle
      refute_received :attacked
    end

    test "a mob in chase drops a target that concealed itself" do
      :ok = StatusStorage.apply_status(:player, 2, :sc_hiding)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {105, 105, "prontera"}}
      end)

      result = think(chase_mob_state())

      assert result.target_ref == nil
      assert result.skill_state == :idle
    end

    test "a boss in combat keeps a target that concealed itself" do
      stub(Interpreter, :concealed?, fn :player, 2 -> true end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Combat, :execute_mob_attack, fn _state, _target -> :ok end)

      base = base_mob_state(modes: [:detector, :status_immune, :knockback_immune])

      state = %MobState{
        base
        | x: 100,
          y: 100,
          skill_state: :berserk,
          target_ref: {:player, 2},
          last_attack_time: nil
      }

      result = think(state)

      assert result.target_ref == {:player, 2}
    end
  end

  describe "target lifecycle while already selected" do
    test "an alert mob drops a target that died after acquisition" do
      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, corpse_player_state(), nil}}
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      state = %MobState{base_mob_state() | skill_state: :idle, target_ref: {:player, 2}}

      result = think(state)

      assert result.target_ref == nil
      assert result.skill_state == :idle
    end

    test "a chasing mob drops a target that died after acquisition" do
      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, corpse_player_state(), nil}}
      end)

      result = think(chase_mob_state())

      assert result.target_ref == nil
      assert result.skill_state == :idle
    end
  end

  describe "process_attacked/1 target change" do
    setup do
      stub(SpatialIndex, :get_unit_position, fn
        :player, 2 -> {:ok, {101, 100, "prontera"}}
        :player, 3 -> {:ok, {100, 101, "prontera"}}
        :player, 4 -> {:ok, {115, 100, "prontera"}}
        :player, 5 -> {:ok, {113, 100, "prontera"}}
        :mob, 1 -> {:ok, {100, 100, "prontera"}}
      end)

      :ok
    end

    test "an idle mob adopts an attacker it can fight back and takes back one rude attack" do
      state = %{attacked_mob(:idle, {:player, 2}) | attacked_count: 1}

      {result, rude?} = AIStateMachine.process_attacked(state)

      refute rude?

      assert {result.target_ref, result.skill_state, result.attacked_count} ==
               {{:player, 2}, :idle, 0}

      assert {result.attacked_ref, result.norm_attacked_ref} == {nil, nil}
    end

    test "a charmed mob adopts its charmer when the charmer hits it" do
      stub(Interpreter, :charmed_against?, fn :mob, 1, 2 -> true end)

      {result, false} = AIStateMachine.process_attacked(attacked_mob(:idle, {:player, 2}))

      assert result.target_ref == {:player, 2}
    end

    test "a mob in its attack state without change_target_melee keeps its target" do
      state = %{attacked_mob(:berserk, {:player, 2}) | target_ref: {:player, 3}}

      {result, false} = AIStateMachine.process_attacked(state)

      assert result.target_ref == {:player, 3}
      assert result.attacked_ref == nil
    end

    test "with change_target_melee the attack state switches only to the norm attacker" do
      modes = [:can_move, :can_attack, :change_target_melee]
      state = %{attacked_mob(:berserk, {:player, 2}, modes) | target_ref: {:player, 3}}

      {kept, false} = AIStateMachine.process_attacked(state)

      {switched, false} =
        AIStateMachine.process_attacked(%{state | norm_attacked_ref: {:player, 2}})

      assert kept.target_ref == {:player, 3}
      assert switched.target_ref == {:player, 2}
    end

    test "an attacker beyond the visual area counts rude attacks and the second fires the event" do
      {first, false} = AIStateMachine.process_attacked(attacked_mob(:idle, {:player, 4}))
      {second, true} = AIStateMachine.process_attacked(%{first | attacked_ref: {:player, 4}})

      assert first.attacked_count == 1
      assert second.attacked_count == 2
      assert second.target_ref == nil
    end

    test "an invincible attacker is never adopted and counts a rude attack" do
      stub(Invincibility, :active?, fn _unit -> true end)

      {result, false} = AIStateMachine.process_attacked(attacked_mob(:idle, {:player, 2}))

      assert result.target_ref == nil
      assert result.attacked_count == 1
    end

    test "self-inflicted damage never counts a rude attack" do
      {result, false} = AIStateMachine.process_attacked(attacked_mob(:idle, {:mob, 1}))

      assert {result.target_ref, result.attacked_count} == {nil, 0}
    end

    test "the current target hitting from beyond reach counts a rude attack" do
      state = %{attacked_mob(:berserk, {:player, 5}) | target_ref: {:player, 5}}

      {result, false} = AIStateMachine.process_attacked(state)

      assert result.target_ref == {:player, 5}
      assert result.attacked_count == 1
    end

    test "an aggressive mob switches to a second attacker in the think of the event" do
      for skill_state <- [:angry, :follow] do
        state = %{
          base_mob_state(modes: [:can_move, :can_attack])
          | skill_state: skill_state,
            target_ref: {:player, 3},
            aggressive: true
        }

        {result, false} =
          state |> MobState.set_attacked({:player, 2}, false) |> AIStateMachine.process_attacked()

        assert result.target_ref == {:player, 2}
      end
    end

    test "an immobile mob held by a reach-blocking status is not reach-blocked during its walk delay" do
      stub(SpatialIndex, :get_unit_position, fn
        :player, 6 -> {:ok, {104, 100, "prontera"}}
        _type, _id -> {:error, :not_found}
      end)

      stub(StatusStorage, :has_status?, fn _type, _id, status -> status == :sc_spiderweb end)

      stub_paths(fn {100, 100}, {103, 100} -> {:ok, [{101, 100}, {102, 100}, {103, 100}]} end)

      held = %{attacked_mob(:berserk, {:player, 6}, [:can_attack]) | target_ref: {:player, 6}}
      delayed = %{held | walk_delay_until: System.monotonic_time(:millisecond) + 60_000}

      {walk_delayed, false} = AIStateMachine.process_attacked(delayed)
      {blocked, false} = AIStateMachine.process_attacked(held)

      assert walk_delayed.attacked_count == 0
      assert blocked.attacked_count == 1
    end

    test "a mob that cannot attack keeps the attacked event pending" do
      state = attacked_mob(:idle, {:player, 2}, [:can_move])

      assert AIStateMachine.process_attacked(state) == {state, false}
    end
  end

  describe "an attacking mob sheds an untargetable target" do
    test "a mob in combat drops a target that became untargetable" do
      test_pid = self()
      stub(Interpreter, :targetable?, fn :player, 2 -> false end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Combat, :execute_mob_attack, fn _state, _target ->
        send(test_pid, :attacked)
        :ok
      end)

      state = combat_mob_state()

      result = think(state)

      assert result.target_ref == nil
      assert result.skill_state == :idle
      refute_received :attacked
    end

    test "a mob in combat retains a still-targetable target" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Combat, :execute_mob_attack, fn _state, _target -> :ok end)

      state = combat_mob_state()

      result = think(state)

      assert result.target_ref == {:player, 2}
    end
  end

  describe "a target gone from the world" do
    test "is dropped at once even while walking, and the think goes on" do
      stub(SpatialIndex, :get_unit_position, fn _type, _id -> {:error, :not_found} end)
      stub(UnitRegistry, :get_unit, fn :player, 2 -> {:error, :not_found} end)
      walking = %{chase_mob_state() | movement_state: :moving, walk_path: [{101, 101}]}

      result = think(walking)

      assert {result.target_ref, result.skill_state} == {nil, :idle}
    end

    test "an invalid target that is still in the world is kept while walking" do
      stub(Interpreter, :targetable?, fn :player, 2 -> false end)
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {105, 105, "prontera"}} end)
      walking = %{chase_mob_state() | movement_state: :moving, walk_path: [{101, 101}]}

      assert think(walking).target_ref == {:player, 2}
    end
  end

  describe "a chasing mob sheds an untargetable target" do
    test "a mob in chase drops a target that became untargetable" do
      stub(Interpreter, :targetable?, fn :player, 2 -> false end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {105, 105, "prontera"}}
      end)

      state = chase_mob_state()

      result = think(state)

      assert result.target_ref == nil
      assert result.skill_state == :idle
    end

    test "a mob in chase retains a still-targetable target" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {105, 105, "prontera"}}
      end)

      state = chase_mob_state()

      result = think(state)

      assert result.target_ref == {:player, 2}
    end
  end

  describe "the chase targets an adjoining cell regardless of occupancy" do
    test "a chasing mob paths to a cell adjacent to the player, never the player's cell" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {105, 105, "prontera"}}
      end)

      {dest_x, dest_y} = destination(think(chase_mob_state()))
      assert {dest_x, dest_y} != {105, 105}
      assert Geometry.chebyshev_distance(dest_x, dest_y, 105, 105) <= 2
    end

    test "keeps the adjoining destination when another unit occupies it" do
      stub(SpatialIndex, :get_unit_position, fn
        :player, 2 -> {:ok, {105, 105, "prontera"}}
        :mob, 55 -> {:ok, {104, 104, "prontera"}}
      end)

      # Another unit already stands on the adjoining approach cell.
      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _range ->
        [{:mob, 55}]
      end)

      assert destination(think(chase_mob_state())) == {104, 104}
    end

    test "uses a corpse cell as an available chase destination" do
      stub(SpatialIndex, :get_unit_position, fn
        :player, 2 -> {:ok, {105, 105, "prontera"}}
        :player, 5000 -> {:ok, {103, 103, "prontera"}}
      end)

      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _range ->
        [{:player, 5000}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :player, 2 -> {:ok, {PlayerState, living_player_state(), nil}}
        :player, 5000 -> {:ok, {PlayerState, corpse_player_state(), nil}}
      end)

      assert destination(think(chase_mob_state())) == {104, 104}
    end

    test "uses an inconsistent player cell as an available chase destination" do
      stub(SpatialIndex, :get_unit_position, fn
        :player, 2 -> {:ok, {105, 105, "prontera"}}
        :player, 5000 -> {:ok, {103, 103, "prontera"}}
      end)

      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _range ->
        [{:player, 5000}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :player, 2 ->
          {:ok, {PlayerState, living_player_state(), nil}}

        :player, 5000 ->
          {:ok,
           {PlayerState, %PlayerState{action_state: :idle, stats: %{current_state: %{hp: 0}}},
            nil}}
      end)

      assert destination(think(chase_mob_state())) == {104, 104}
    end

    test "re-picks another adjacent cell when dynamic terrain blocks the nearest cell" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {105, 105, "prontera"}}
      end)

      stub(Cell, :traversable?, fn "prontera", x, y -> {x, y} != {104, 104} end)
      {dest_x, dest_y} = destination(think(chase_mob_state()))
      assert {dest_x, dest_y} == {105, 104}
      assert {dest_x, dest_y} != {105, 105}
      assert Geometry.chebyshev_distance(dest_x, dest_y, 105, 105) <= 2
    end
  end

  defp think(state, now \\ System.system_time(:millisecond)),
    do: AIStateMachine.process_ai(state, now)

  defp destination(%MobState{walk_path: path}), do: List.last(path)

  # A straight path, one cell per step along each axis.
  defp stub_paths(path_fun) do
    stub(Pathfinding, :find_path, fn _map, from, to -> path_fun.(from, to) end)
    stub(Pathfinding, :find_path, fn _map, from, to, _opts -> path_fun.(from, to) end)
    stub(Pathfinding, :walk_path, fn _map, from, to -> path_fun.(from, to) end)
    stub(Pathfinding, :rewalk_path, fn _map, from, to -> path_fun.(from, to) end)
    stub(Pathfinding, :rewalk_path, fn _map, from, to, _opts -> path_fun.(from, to) end)
  end

  defp line_path({fx, fy}, {tx, ty}) do
    steps = max(abs(tx - fx), abs(ty - fy))

    Enum.map(1..steps//1, fn i ->
      {fx + sign(tx - fx) * min(i, abs(tx - fx)), fy + sign(ty - fy) * min(i, abs(ty - fy))}
    end)
  end

  defp sign(n) when n > 0, do: 1
  defp sign(n) when n < 0, do: -1
  defp sign(_n), do: 0

  defp walk_time(%MobState{walk_path: path, walk_speed: speed, x: x, y: y}) do
    [{x, y} | path]
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(0, fn [{x1, y1}, {x2, y2}], acc ->
      if x1 != x2 and y1 != y2, do: acc + div(speed * 14, 10), else: acc + speed
    end)
  end

  defp aggressive_idle_mob_state(opts \\ [modes: [:aggressive]]) do
    %MobState{base_mob_state(opts) | x: 100, y: 100, skill_state: :idle, target_ref: nil}
  end

  defp chase_mob_state(opts \\ [modes: [:can_move, :can_attack]]) do
    %MobState{
      base_mob_state(opts)
      | x: 100,
        y: 100,
        skill_state: :rush,
        target_ref: {:player, 2},
        movement_state: :standing,
        process_pid: self()
    }
  end

  defp movable_mob_state(opts \\ [modes: [:can_move]]) do
    %MobState{
      base_mob_state(opts)
      | process_pid: self(),
        x: 100,
        y: 100,
        movement_state: :standing
    }
  end

  defp combat_mob_state(opts \\ [modes: [:can_move, :can_attack]]) do
    %MobState{
      base_mob_state(opts)
      | x: 100,
        y: 100,
        skill_state: :berserk,
        target_ref: {:player, 2},
        last_attack_time: nil
    }
  end

  defp corpse_player_state do
    %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}
  end

  defp living_player_state do
    %PlayerState{action_state: :idle, stats: %{current_state: %{hp: 100}}}
  end

  defp leveled_player(base_level) do
    PlayerState.new(%Character{
      id: 2,
      account_id: 100,
      name: "Target",
      last_map: "prontera",
      last_x: 104,
      last_y: 100,
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
      base_level: base_level,
      job_level: 1,
      class: 0
    })
  end

  defp homunculus_state(owner_character_id) do
    %HomunculusState{
      id: 501,
      owner_character_id: owner_character_id,
      owner_session_pid: self(),
      class_id: 6_001,
      name: "Test Homunculus",
      lifecycle: :active,
      level: 50,
      exp: 0,
      skill_points: 0,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      str: 30,
      agi: 25,
      vit: 20,
      int: 15,
      dex: 35,
      luk: 10,
      hunger: 80,
      intimacy_hundredths: 9_500,
      active_remaining_ms: 1_000_000,
      learned_skills: %{},
      cooldowns: %{},
      ai_config: %{},
      world_gid: 501,
      map_name: "prontera",
      x: 100,
      y: 100,
      dir: 4,
      action_state: :idle,
      movement_state: :standing,
      target: nil,
      casting: nil,
      race: :demi_human,
      element: {:neutral, 1},
      size: :medium,
      attack_range: 1,
      attack_delay_ms: 500,
      combat_stats: %{
        atk: 50,
        def: 20,
        hit: 100,
        flee: 80,
        perfect_dodge: 0,
        matk: 30,
        matk_min: 25,
        matk_max: 35,
        mdef: 10,
        soft_mdef: 0
      }
    }
  end

  defp attacked_mob(skill_state, attacker, modes \\ [:can_move, :can_attack]) do
    %MobState{base_mob_state(modes: modes) | skill_state: skill_state, attacked_ref: attacker}
  end

  defp base_mob_state(opts \\ []) do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 2,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      modes: Keyword.get(opts, :modes, [])
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
  end
end
