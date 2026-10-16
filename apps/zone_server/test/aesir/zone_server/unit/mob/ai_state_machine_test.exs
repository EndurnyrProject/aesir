defmodule Aesir.ZoneServer.Unit.Mob.AIStateMachineTest do
  @moduledoc """
  Verifies mob self-gating: a mob carrying a `no_move` / `no_attack` status does
  not issue movement or attack on its AI tick (design §4 mob self-gating rows).
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

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
  alias Aesir.ZoneServer.Unit.Mob.MobSession
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
    Mimic.copy(MobSession)
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

    stub(UnitRegistry, :get_unit, fn :player, _id ->
      {:ok, {PlayerState, living_player_state(), nil}}
    end)

    :ok
  end

  describe "move_toward/3 status gating" do
    test "a no_move mob does not issue movement and its state is unchanged" do
      test_pid = self()
      stub(MobSession, :move_to, fn _pid, _x, _y -> send(test_pid, :moved) end)
      stub(Interpreter, :can_move?, fn :mob, 1 -> false end)

      state = movable_mob_state()

      assert AIStateMachine.move_toward(state, 105, 105) == state
      refute_received :moved
    end

    test "an unafflicted mob issues movement as before" do
      test_pid = self()
      stub(MobSession, :move_to, fn _pid, x, y -> send(test_pid, {:moved, x, y}) end)

      state = movable_mob_state()

      assert AIStateMachine.move_toward(state, 105, 105) == state
      assert_received {:moved, 105, 105}
    end
  end

  describe "idle random walk" do
    test "only a mob that can move and is not barred from random walks wanders" do
      wanders? = fn modes ->
        :rand.seed(:exsss, {1, 2, 3})
        state = base_mob_state(modes: modes)

        Enum.any?(1..60, fn _ ->
          AIStateMachine.process_ai(state).last_idle_movement_time != nil
        end)
      end

      assert wanders?.([:can_move])
      refute wanders?.([])
      refute wanders?.([:can_move, :no_random_walk])
    end
  end

  describe "settling the pending exit from aggressive mode" do
    setup do
      stub(MobSession, :move_to, fn _pid, _x, _y -> :ok end)
      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range -> [] end)
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {105, 105, "prontera"}} end)
      :ok
    end

    test "an idle mob settles it when a random walk starts, so a later aggro is self-initiated" do
      :rand.seed(:exsss, {1, 2, 3})

      state = %{
        movable_mob_state()
        | mob_data: %{base_mob_state().mob_data | modes: [:can_move, :aggressive]},
          left_aggressive?: true
      }

      walked =
        Enum.reduce_while(1..60, state, fn _, acc ->
          next = AIStateMachine.process_ai(acc)
          if next.last_idle_movement_time, do: {:halt, next}, else: {:cont, next}
        end)

      assert walked.last_idle_movement_time
      refute walked.left_aggressive?

      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range -> [2] end)
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {101, 101, "prontera"}} end)

      assert AIStateMachine.check_aggro(walked).initiated_by_self?
    end

    test "an idle mob that does not walk keeps it" do
      state = %{base_mob_state(modes: [:aggressive]) | left_aggressive?: true}

      assert AIStateMachine.process_ai(state).left_aggressive?
    end

    test "a chasing mob already walking keeps it" do
      state = %{
        chase_mob_state()
        | movement_state: :moving,
          initiated_by_self?: true,
          left_aggressive?: true
      }

      result = AIStateMachine.process_ai(state)

      assert result.left_aggressive?
      assert MobState.skill_state(result) == :follow
    end

    test "a chasing mob settles it when it starts a walk" do
      state = %{chase_mob_state() | initiated_by_self?: true, left_aggressive?: true}

      result = AIStateMachine.process_ai(state)

      assert MobState.skill_state(result) == :rush
    end

    test "a swing the combat system refuses keeps it" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {100, 100, "prontera"}} end)
      stub(Combat, :execute_mob_attack, fn _state, _target -> {:error, :invalid_target} end)
      state = %{combat_mob_state() | initiated_by_self?: true, left_aggressive?: true}

      result = AIStateMachine.process_ai(state)

      assert result.left_aggressive?
      assert MobState.skill_state(result) == :angry
    end

    test "a swing that lands settles it" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {100, 100, "prontera"}} end)
      stub(Combat, :execute_mob_attack, fn _state, _target -> :ok end)
      state = %{combat_mob_state() | initiated_by_self?: true, left_aggressive?: true}

      assert MobState.skill_state(AIStateMachine.process_ai(state)) == :berserk
    end
  end

  describe "execute_mob_attack via process_ai status gating" do
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

      result = AIStateMachine.process_ai(state)

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

      result = AIStateMachine.process_ai(state)

      assert_received :attacked
      assert result.last_attack_time != nil
    end

    test "a landed swing rests the AI for the mob's attack motion" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 -> {:ok, {100, 100, "prontera"}} end)
      stub(Combat, :execute_mob_attack, fn _state, _target -> :ok end)
      state = combat_mob_state()

      result = AIStateMachine.process_ai(state)

      assert result.next_think_at == result.last_attack_time + MobState.get_attack_motion(state)
    end
  end

  describe "find_nearby_targets/1 targeting filter via process_ai aggro" do
    test "an untargetable (trick-dead) player is not acquired by an idle aggressive mob" do
      stub(Interpreter, :targetable?, fn :player, 2 -> false end)

      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      state = aggressive_idle_mob_state()

      result = AIStateMachine.process_ai(state)

      assert result.target_ref == nil
      assert result.ai_state == :idle
    end

    test "a corpse is not acquired by an idle aggressive mob" do
      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, corpse_player_state(), nil}}
      end)

      result = AIStateMachine.process_ai(aggressive_idle_mob_state())

      assert result.target_ref == nil
      assert result.ai_state == :idle
    end

    test "a player missing its authoritative snapshot is not acquired" do
      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 -> {:error, :not_found} end)

      result = AIStateMachine.process_ai(aggressive_idle_mob_state())

      assert result.target_ref == nil
      assert result.ai_state == :idle
    end

    test "a player in Gangster Paradise is not acquired by an idle aggressive mob" do
      stub(StatusStorage, :has_status?, fn :player, 2, :sc_gangsterparadise -> true end)

      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      result = AIStateMachine.process_ai(aggressive_idle_mob_state())

      assert result.target_ref == nil
      assert result.ai_state == :idle
    end

    test "an invincible player is not acquired by an idle aggressive mob" do
      stub(Invincibility, :active?, fn _unit -> true end)

      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      result = AIStateMachine.process_ai(aggressive_idle_mob_state())

      assert result.target_ref == nil
      assert result.ai_state == :idle
    end

    test "a targetable player is acquired by an idle aggressive mob" do
      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      state = aggressive_idle_mob_state()

      result = AIStateMachine.process_ai(state)

      assert result.target_ref == {:player, 2}
      assert result.ai_state == :alert
    end

    test "aggro acquired by scan marks the combat as self-initiated" do
      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      state = aggressive_idle_mob_state()

      result = AIStateMachine.check_aggro(state)

      assert result.target_ref == {:player, 2}
      assert result.ai_state == :alert
      assert result.initiated_by_self? == true
    end
  end

  describe "owner-aware hostility in the aggro scan" do
    test "a mob does not acquire a living player from its own guild" do
      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 7}, nil}}
      end)

      state = %MobState{aggressive_idle_mob_state() | guild_id: 7}

      result = AIStateMachine.check_aggro(state)

      assert result.target_ref == nil
      assert result.ai_state == :idle
    end

    test "a mob acquires a living player from a different guild" do
      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 8}, nil}}
      end)

      state = %MobState{aggressive_idle_mob_state() | guild_id: 7}

      result = AIStateMachine.check_aggro(state)

      assert result.target_ref == {:player, 2}
      assert result.ai_state == :alert
    end

    test "a mob does not acquire a living player from an allied guild" do
      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 9}, nil}}
      end)

      stub(Relations, :friendly?, fn 7, 9 -> true end)

      state = %MobState{aggressive_idle_mob_state() | guild_id: 7}

      result = AIStateMachine.check_aggro(state)

      assert result.target_ref == nil
      assert result.ai_state == :idle
    end

    test "a mob still acquires a living player from an unrelated guild" do
      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 8}, nil}}
      end)

      stub(Relations, :friendly?, fn 7, 8 -> false end)

      state = %MobState{aggressive_idle_mob_state() | guild_id: 7}

      result = AIStateMachine.check_aggro(state)

      assert result.target_ref == {:player, 2}
      assert result.ai_state == :alert
    end

    test "a guildless mob still acquires a player belonging to a guild" do
      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 7}, nil}}
      end)

      result = AIStateMachine.check_aggro(aggressive_idle_mob_state())

      assert result.target_ref == {:player, 2}
      assert result.ai_state == :alert
    end

    test "a mob does not acquire a homunculus whose owner shares its guild" do
      stub(SpatialIndex, :get_units_in_range, fn :player, _map, _x, _y, _range -> [] end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 100, 100, _range ->
        [{:homunculus, 501}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :homunculus, 501 ->
          {:ok, {HomunculusState, homunculus_state(42), nil}}

        :player, 42 ->
          {:ok, {PlayerState, %PlayerState{living_player_state() | guild_id: 7}, nil}}
      end)

      state = %MobState{aggressive_idle_mob_state() | guild_id: 7}

      result = AIStateMachine.check_aggro(state)

      assert result.target_ref == nil
      assert result.ai_state == :idle
    end

    test "a mob acquires a homunculus whose owner belongs to a different guild" do
      stub(SpatialIndex, :get_units_in_range, fn :player, _map, _x, _y, _range -> [] end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 100, 100, _range ->
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

      result = AIStateMachine.check_aggro(state)

      assert result.target_ref == {:homunculus, 501}
      assert result.ai_state == :alert
    end

    test "a guild-owned mob does not acquire a homunculus whose owner's guild is allied" do
      stub(SpatialIndex, :get_units_in_range, fn :player, _map, _x, _y, _range -> [] end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 100, 100, _range ->
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

      result = AIStateMachine.check_aggro(state)

      assert result.target_ref == nil
      assert result.ai_state == :idle
    end

    test "a guild-owned mob acquires a homunculus whose owner's guild is unrelated" do
      stub(SpatialIndex, :get_units_in_range, fn :player, _map, _x, _y, _range -> [] end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 100, 100, _range ->
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

      result = AIStateMachine.check_aggro(state)

      assert result.target_ref == {:homunculus, 501}
      assert result.ai_state == :alert
    end

    test "an ordinary mob acquiring a homunculus never resolves the owner's guild" do
      stub(SpatialIndex, :get_units_in_range, fn :player, _map, _x, _y, _range -> [] end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 100, 100, _range ->
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

      result = AIStateMachine.check_aggro(aggressive_idle_mob_state())

      assert result.target_ref == {:homunculus, 501}
      assert result.ai_state == :alert
    end
  end

  describe "find_nearby_targets/1 concealment filter" do
    test "a concealed player is not acquired by a normal mob" do
      :ok = StatusStorage.apply_status(:player, 2, :sc_cloaking)

      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      result = AIStateMachine.process_ai(aggressive_idle_mob_state())

      assert result.target_ref == nil
      assert result.ai_state == :idle
    end

    test "a concealed player is acquired by a boss mob, which acts as a detector" do
      :ok = StatusStorage.apply_status(:player, 2, :sc_cloaking)

      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      base = base_mob_state(modes: [:aggressive, :boss])
      state = %MobState{base | x: 100, y: 100, ai_state: :idle, target_ref: nil}

      result = AIStateMachine.process_ai(state)

      assert result.target_ref == {:player, 2}
      assert result.ai_state == :alert
    end

    test "a concealed player is acquired by a non-boss detector mob" do
      :ok = StatusStorage.apply_status(:player, 2, :sc_cloaking)

      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      base = base_mob_state(modes: [:aggressive, :detector])
      state = %MobState{base | x: 100, y: 100, ai_state: :idle, target_ref: nil}

      result = AIStateMachine.process_ai(state)

      assert result.target_ref == {:player, 2}
    end

    test "a player who un-conceals is acquirable again by a normal mob" do
      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      :ok = StatusStorage.apply_status(:player, 2, :sc_hiding)

      concealed = AIStateMachine.process_ai(aggressive_idle_mob_state())

      assert concealed.target_ref == nil

      :ok = StatusStorage.remove_status(:player, 2, :sc_hiding)

      revealed = AIStateMachine.process_ai(aggressive_idle_mob_state())

      assert revealed.target_ref == {:player, 2}
      assert revealed.ai_state == :alert
    end
  end

  describe "wink of charm targeting" do
    test "a charmed mob drops the Dancer it already targets" do
      stub(Interpreter, :charmed_against?, fn :mob, 1, 2 -> true end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Combat, :execute_mob_attack, fn _state, _target -> :ok end)

      result = AIStateMachine.process_ai(combat_mob_state())

      assert result.target_ref == nil
      assert result.ai_state == :idle
    end

    test "a charmed mob acquires a different player" do
      stub(Interpreter, :charmed_against?, fn :mob, 1, target_id -> target_id == 2 end)

      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2, 3]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 3 ->
        {:ok, {101, 101, "prontera"}}
      end)

      result = AIStateMachine.process_ai(aggressive_idle_mob_state())

      assert result.target_ref == {:player, 3}
      assert result.ai_state == :alert
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
        |> AIStateMachine.process_ai()

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

      result = AIStateMachine.process_ai(combat_mob_state())

      assert result.target_ref == nil
      assert result.ai_state == :idle
      refute_received :attacked
    end

    test "a mob in chase drops a target that concealed itself" do
      :ok = StatusStorage.apply_status(:player, 2, :sc_hiding)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {105, 105, "prontera"}}
      end)

      stub(MobSession, :move_to, fn _pid, _x, _y -> :ok end)

      result = AIStateMachine.process_ai(chase_mob_state())

      assert result.target_ref == nil
      assert result.ai_state == :return
    end

    test "a boss in combat keeps a target that concealed itself" do
      stub(Interpreter, :concealed?, fn :player, 2 -> true end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Combat, :execute_mob_attack, fn _state, _target -> :ok end)

      base = base_mob_state(modes: [:boss])

      state = %MobState{
        base
        | x: 100,
          y: 100,
          ai_state: :combat,
          target_ref: {:player, 2},
          last_attack_time: nil
      }

      result = AIStateMachine.process_ai(state)

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

      state = %MobState{base_mob_state() | ai_state: :alert, target_ref: {:player, 2}}

      result = AIStateMachine.process_ai(state)

      assert result.target_ref == nil
      assert result.ai_state == :idle
    end

    test "a chasing mob drops a target that died after acquisition" do
      stub(UnitRegistry, :get_unit, fn :player, 2 ->
        {:ok, {PlayerState, corpse_player_state(), nil}}
      end)

      result = AIStateMachine.process_ai(chase_mob_state())

      assert result.target_ref == nil
      assert result.ai_state == :return
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

      assert {result.target_ref, result.ai_state, result.attacked_count} ==
               {{:player, 2}, :combat, 0}

      assert {result.attacked_ref, result.norm_attacked_ref} == {nil, nil}
    end

    test "a mob in its attack state without change_target_melee keeps its target" do
      state = %{attacked_mob(:combat, {:player, 2}) | target_ref: {:player, 3}}

      {result, false} = AIStateMachine.process_attacked(state)

      assert result.target_ref == {:player, 3}
      assert result.attacked_ref == nil
    end

    test "with change_target_melee the attack state switches only to the norm attacker" do
      modes = [:can_move, :can_attack, :change_target_melee]
      state = %{attacked_mob(:combat, {:player, 2}, modes) | target_ref: {:player, 3}}

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
      state = %{attacked_mob(:combat, {:player, 5}) | target_ref: {:player, 5}}

      {result, false} = AIStateMachine.process_attacked(state)

      assert result.target_ref == {:player, 5}
      assert result.attacked_count == 1
    end

    test "an aggressive mob switches to a second attacker in the think of the event" do
      for ai_state <- [:combat, :chase] do
        state = %{
          base_mob_state(modes: [:can_move, :can_attack])
          | ai_state: ai_state,
            target_ref: {:player, 3},
            initiated_by_self?: true
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

      stub(Pathfinding, :find_path, fn _map, {100, 100}, {103, 100}, _opts ->
        {:ok, [{101, 100}, {102, 100}, {103, 100}]}
      end)

      held = %{attacked_mob(:combat, {:player, 6}, [:can_attack]) | target_ref: {:player, 6}}
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

  describe "process_combat/1 sheds aggro on untargetable target" do
    test "a mob in combat drops a target that became untargetable (return to idle)" do
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

      result = AIStateMachine.process_ai(state)

      assert result.target_ref == nil
      assert result.ai_state == :idle
      refute_received :attacked
    end

    test "a mob in combat retains a still-targetable target" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Combat, :execute_mob_attack, fn _state, _target -> :ok end)

      state = combat_mob_state()

      result = AIStateMachine.process_ai(state)

      assert result.target_ref == {:player, 2}
    end
  end

  describe "process_chase/1 sheds aggro on untargetable target" do
    test "a mob in chase drops a target that became untargetable (return to spawn)" do
      stub(Interpreter, :targetable?, fn :player, 2 -> false end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {105, 105, "prontera"}}
      end)

      stub(MobSession, :move_to, fn _pid, _x, _y -> :ok end)

      state = chase_mob_state()

      result = AIStateMachine.process_ai(state)

      assert result.target_ref == nil
      assert result.ai_state == :return
    end

    test "a mob in chase retains a still-targetable target" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {105, 105, "prontera"}}
      end)

      stub(MobSession, :move_to, fn _pid, _x, _y -> :ok end)

      state = chase_mob_state()

      result = AIStateMachine.process_ai(state)

      assert result.target_ref == {:player, 2}
      assert result.ai_state in [:chase, :combat, :alert]
    end
  end

  describe "process_chase/1 targets an adjacent, unoccupied cell" do
    test "a chasing mob paths to a cell adjacent to the player, never the player's cell" do
      test_pid = self()

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {105, 105, "prontera"}}
      end)

      stub(MobSession, :move_to, fn _pid, x, y -> send(test_pid, {:moved, x, y}) end)

      AIStateMachine.process_ai(chase_mob_state())

      assert_received {:moved, dest_x, dest_y}
      assert {dest_x, dest_y} != {105, 105}
      assert Geometry.chebyshev_distance(dest_x, dest_y, 105, 105) <= 2
    end

    test "re-picks another adjacent cell when the best cell is occupied" do
      test_pid = self()

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2 -> {:ok, {105, 105, "prontera"}}
        :mob, 55 -> {:ok, {103, 103, "prontera"}}
      end)

      # (103,103) is the closest walkable adjacent cell along the approach; a
      # second unit sitting there must be avoided rather than overlapped.
      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _range ->
        [{:mob, 55}]
      end)

      stub(MobSession, :move_to, fn _pid, x, y -> send(test_pid, {:moved, x, y}) end)

      AIStateMachine.process_ai(chase_mob_state())

      assert_received {:moved, dest_x, dest_y}
      assert {dest_x, dest_y} != {103, 103}
      assert {dest_x, dest_y} != {105, 105}
      assert Geometry.chebyshev_distance(dest_x, dest_y, 105, 105) <= 2
    end

    test "uses a corpse cell as an available chase destination" do
      test_pid = self()

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

      stub(MobSession, :move_to, fn _pid, x, y -> send(test_pid, {:moved, x, y}) end)

      AIStateMachine.process_ai(chase_mob_state())

      assert_received {:moved, 103, 103}
    end

    test "uses an inconsistent player cell as an available chase destination" do
      test_pid = self()

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

      stub(MobSession, :move_to, fn _pid, x, y -> send(test_pid, {:moved, x, y}) end)

      AIStateMachine.process_ai(chase_mob_state())

      assert_received {:moved, 103, 103}
    end

    test "re-picks another adjacent cell when dynamic terrain blocks the nearest cell" do
      test_pid = self()

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {105, 105, "prontera"}}
      end)

      stub(Cell, :traversable?, fn "prontera", x, y -> {x, y} != {103, 103} end)
      stub(MobSession, :move_to, fn _pid, x, y -> send(test_pid, {:moved, x, y}) end)

      AIStateMachine.process_ai(chase_mob_state())

      assert_received {:moved, dest_x, dest_y}
      assert {dest_x, dest_y} != {103, 103}
      assert {dest_x, dest_y} != {105, 105}
      assert Geometry.chebyshev_distance(dest_x, dest_y, 105, 105) <= 2
    end
  end

  describe "spawn anchoring" do
    test "spawn checks anchor on the cell the mob spawned at, not the raw spawn config" do
      # Imported rAthena spawn lines use x/y 0,0 ("random cell anywhere"); the
      # AI must anchor on the resolved spawn_point or every mob would try to
      # wander to and return toward the map corner.
      state = %MobState{
        base_mob_state()
        | spawn_ref: %MobSpawn{
            mob: 1001,
            amount: 1,
            respawn_time: 5000,
            spawn_area: %SpawnArea{x: 0, y: 0}
          }
      }

      assert AIStateMachine.at_spawn_area?(state)
      refute AIStateMachine.should_return_to_spawn?(state)
    end

    test "a mob far from its spawn point wants to return to it" do
      state = %MobState{base_mob_state() | x: 200, y: 200}

      refute AIStateMachine.at_spawn_area?(state)
      assert AIStateMachine.should_return_to_spawn?(state)
    end
  end

  defp aggressive_idle_mob_state do
    base = base_mob_state(modes: [:aggressive])

    %MobState{base | x: 100, y: 100, ai_state: :idle, target_ref: nil}
  end

  defp chase_mob_state do
    %MobState{
      base_mob_state()
      | x: 100,
        y: 100,
        ai_state: :chase,
        target_ref: {:player, 2},
        movement_state: :standing,
        process_pid: self()
    }
  end

  defp movable_mob_state do
    %MobState{
      base_mob_state()
      | process_pid: self(),
        x: 100,
        y: 100,
        movement_state: :standing,
        last_movement_end_time: nil
    }
  end

  defp combat_mob_state do
    %MobState{
      base_mob_state()
      | x: 100,
        y: 100,
        ai_state: :combat,
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

  defp attacked_mob(ai_state, attacker, modes \\ [:can_move, :can_attack]) do
    %MobState{base_mob_state(modes: modes) | ai_state: ai_state, attacked_ref: attacker}
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
