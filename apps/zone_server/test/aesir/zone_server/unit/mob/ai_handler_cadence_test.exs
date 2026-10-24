defmodule Aesir.ZoneServer.Unit.Mob.AiHandlerCadenceTest do
  @moduledoc """
  Verifies the AI think cadence: the hard think the map sends per nearby
  player spots the mob and skips a resting one; the mob's own 1 s tick runs the
  lazy think, which drops the target, wanders and checks idle skills only for
  a spotted mob; the attack timer and the walk-delayed chase resume are armed
  as messages at their times; the periodic skill check keeps its interval and
  the spawn event fires only onspawn rows.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.MobSkill.Db, as: MobSkillDb
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  # A private seeded status table keeps another async test's status on the
  # same mob instance id from leaking into this file.
  setup :setup_ets_tables

  @target {:player, 42}

  setup do
    Mimic.copy(Cell)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(StatusStorage, :has_status?, fn _unit_type, _unit_id, _status -> false end)
    stub(StatusInterpreter, :targetable?, fn :player, _id -> true end)
    stub(StatusInterpreter, :can_attack?, fn :mob, 1 -> true end)
    stub(StatusInterpreter, :loses_target?, fn :mob, 1 -> false end)
    stub(MobSkillDb, :rows_for, fn 1001 -> [] end)
    stub(Combat, :execute_mob_attack, fn _state, _target -> :ok end)
    stub(MapCache, :get, fn _map -> {:ok, :map_data} end)
    stub(Cell, :traversable?, fn "prontera", _x, _y -> true end)
    stub(Pathfinding, :find_path, fn _map, _from, {x, y} -> {:ok, [{x, y}]} end)
    stub(Pathfinding, :find_path, fn _map, _from, {x, y}, _opts -> {:ok, [{x, y}]} end)
    stub(Pathfinding, :walk_path, fn _map, _from, {x, y} -> {:ok, [{x, y}]} end)
    stub(Pathfinding, :rewalk_path, fn _map, _from, {x, y} -> {:ok, [{x, y}]} end)
    stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _range -> [] end)
    stub(SpatialIndex, :units_in_area, fn _map, _x1, _y1, _x2, _y2 -> [] end)

    stub(UnitRegistry, :get_unit, fn
      :player, 42 ->
        {:ok, {nil, %PlayerState{action_state: :idle, stats: %{current_state: %{hp: 100}}}, nil}}

      _type, _id ->
        {:error, :not_found}
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :player, 42 -> {:ok, {101, 100, "prontera"}}
      _type, _id -> {:error, :not_found}
    end)

    :ok
  end

  defp hard(state, player_id \\ 42) do
    {:noreply, updated} = AiHandler.handle_hard_think(state, player_id)
    updated
  end

  defp tick(state) do
    {:noreply, updated} = AiHandler.handle_ai_tick(state)
    updated
  end

  describe "hard think" do
    test "a hard think from a player spots the mob and attacks the target in range" do
      thought = hard(mob_state())

      assert thought.attack_target == @target
      assert is_integer(thought.last_attack_time)
      assert thought.spotted_by == MapSet.new([42])
      assert thought.attack_timer_at == thought.last_attack_time + 1200
      assert_receive {:ai, {:attack_timer, at}}, 1500
      assert at == thought.attack_timer_at
    end

    test "a resting mob does not think until its rest ends" do
      now = System.system_time(:millisecond)
      resting = %{mob_state() | next_think_at: now + 60_000}

      thought = hard(resting)

      assert thought.attack_target == nil
      assert thought.next_think_at == now + 60_000
    end

    test "a mob thinks once per nearby player on the same tick" do
      expect(MobSkillDb, :rows_for, 2, fn 1001 -> [] end)
      now = System.system_time(:millisecond)
      idle = %{mob_state() | target_ref: nil, skill_state: :idle, last_skillcheck: now - 1000}

      idle |> hard(42) |> Map.put(:last_skillcheck, now - 1000) |> hard(43)
    end

    test "a dormant or dead mob ignores the hard think" do
      reject(&Combat.execute_mob_attack/2)

      assert hard(%{mob_state() | ai_awake: false}).attack_target == nil
      assert hard(%{mob_state() | is_dead: true}).attack_target == nil
    end

    test "the attack timer's end swings and re-arms the timer, with no player near" do
      now = System.system_time(:millisecond)

      attacking = %{
        mob_state()
        | attack_target: @target,
          attack_timer_at: now - 1,
          last_attack_time: now - 1200
      }

      {:noreply, thought} = AiHandler.handle_attack_timer(attacking, now - 1)

      assert thought.last_attack_time >= now
      assert thought.attack_timer_at == thought.last_attack_time + 1200
    end

    test "a stale attack timer message is ignored" do
      reject(&Combat.execute_mob_attack/2)
      now = System.system_time(:millisecond)
      attacking = %{mob_state() | attack_target: @target, attack_timer_at: now + 500}

      assert {:noreply, ^attacking} = AiHandler.handle_attack_timer(attacking, now - 1)
    end

    test "the attack timer's end cancels the attack and unlocks a target that vanished" do
      reject(&Combat.execute_mob_attack/2)
      stub(SpatialIndex, :get_unit_position, fn _type, _id -> {:error, :not_found} end)
      now = System.system_time(:millisecond)
      attacking = %{mob_state() | attack_target: @target, attack_timer_at: now - 1}

      {:noreply, thought} = AiHandler.handle_attack_timer(attacking, now - 1)

      assert {thought.target_ref, thought.attack_target, thought.skill_state} == {nil, nil, :idle}
    end

    test "a mob that cannot attack drops its attack order" do
      stub(StatusInterpreter, :can_attack?, fn :mob, 1 -> false end)
      reject(&Combat.execute_mob_attack/2)

      thought = hard(mob_state())

      assert {thought.attack_target, thought.attack_timer_at} == {nil, nil}
    end

    test "an armed attack timer only switches the attack target" do
      reject(&Combat.execute_mob_attack/2)
      now = System.system_time(:millisecond)
      stub(SpatialIndex, :get_unit_position, fn :player, _id -> {:ok, {101, 100, "prontera"}} end)

      stub(UnitRegistry, :get_unit, fn :player, _id ->
        {:ok, {nil, %PlayerState{action_state: :idle, stats: %{current_state: %{hp: 100}}}, nil}}
      end)

      armed = %{
        mob_state()
        | skill_state: :idle,
          attack_target: {:player, 43},
          attack_timer_at: now + 500,
          last_attack_time: now - 700
      }

      thought = hard(armed)

      assert {thought.attack_target, thought.skill_state, thought.attack_timer_at} ==
               {@target, :idle, now + 500}
    end

    test "a walk-delayed chase books its resume one millisecond after the delay" do
      mono = System.monotonic_time(:millisecond)
      stub(SpatialIndex, :get_unit_position, fn :player, 42 -> {:ok, {106, 100, "prontera"}} end)
      delayed = %{mob_state() | skill_state: :rush, walk_delay_until: mono + 40}

      thought = hard(delayed)

      assert thought.chase_resume_at == mono + 41
      assert thought.movement_state == :standing
      assert_receive {:ai, {:chase_resume, at}}, 500
      assert at == thought.chase_resume_at

      {:noreply, resumed} = AiHandler.handle_chase_resume(%{thought | walk_delay_until: 0}, at)

      assert {resumed.movement_state, resumed.skill_state, resumed.chase_resume_at} ==
               {:moving, :rush, nil}
    end

    test "the periodic skill check runs once per second outside the attack state" do
      expect(MobSkillDb, :rows_for, 1, fn 1001 -> [] end)
      now = System.system_time(:millisecond)
      idle = %{mob_state() | target_ref: nil, skill_state: :idle, last_skillcheck: now - 500}

      unchecked = hard(idle)
      assert unchecked.last_skillcheck == now - 500

      checked = hard(%{idle | last_skillcheck: now - 1000})
      assert checked.last_skillcheck >= now
    end

    test "the attack state checks skills when the attack delay has ended" do
      reject(&MobSkillDb.rows_for/1)
      now = System.system_time(:millisecond)

      hard(%{
        mob_state()
        | attack_target: @target,
          attack_timer_at: now + 1100,
          last_attack_time: now - 100
      })
    end

    test "the spawn event fires only onspawn rows and leaves the skill interval alone" do
      now = System.system_time(:millisecond)
      row = %{row() | condition: %{type: :onspawn}}
      stub(MobSkillDb, :rows_for, fn 1001 -> [row, row()] end)

      thought = hard(%{mob_state() | spawn_tick_pending?: true, last_skillcheck: now})

      assert %{row: ^row} = thought.casting
      assert thought.last_skillcheck == now
      Process.cancel_timer(thought.casting.timer_ref)
    end
  end

  describe "skill event" do
    setup do
      player =
        PlayerStateFixture.build(%{
          character_id: 42,
          map_name: "prontera",
          x: 101,
          y: 100,
          stats: %{}
        })

      stub(UnitRegistry, :get_unit, fn
        :player, 42 -> {:ok, {PlayerState, player, nil}}
        :mob, 7 -> {:ok, {MobState, %{mob_state() | instance_id: 7}, nil}}
        _type, _id -> {:error, :not_found}
      end)

      :ok
    end

    defp skill_used_row(skill_id, target \\ :target) do
      %{row() | state: :any, target: target, condition: %{type: :skillused, value: skill_id}}
    end

    defp skill_event(state, source, skill_id) do
      now = System.system_time(:millisecond)

      {:noreply, updated} =
        AiHandler.handle_skill_event(state, source, {:skillused, skill_id}, now)

      if updated.casting, do: Process.cancel_timer(updated.casting.timer_ref)
      updated
    end

    test "a target-less mob reacts to an enemy's skill and keeps the enemy as its target" do
      stub(MobSkillDb, :rows_for, fn 1001 -> [skill_used_row(28)] end)

      reacted = skill_event(%{mob_state() | target_ref: nil, skill_state: :idle}, @target, 28)

      assert %{row: %{skill_id: 19}} = reacted.casting
      assert reacted.target_ref == @target
    end

    test "the previous target comes back when no row fires" do
      stub(MobSkillDb, :rows_for, fn 1001 -> [skill_used_row(50)] end)

      unmoved = skill_event(%{mob_state() | target_ref: nil, skill_state: :idle}, @target, 28)

      assert {unmoved.casting, unmoved.target_ref} == {nil, nil}
    end

    test "the previous target comes back when the source is not an enemy" do
      stub(MobSkillDb, :rows_for, fn 1001 -> [skill_used_row(28, :self)] end)

      reacted = skill_event(%{mob_state() | target_ref: nil, skill_state: :idle}, {:mob, 7}, 28)

      assert reacted.casting != nil
      assert reacted.target_ref == nil
    end

    test "a casting mob picks nothing and keeps its target" do
      reject(&MobSkillDb.rows_for/1)
      casting = %{mob_state() | target_ref: nil, casting: %{timer_ref: make_ref()}}

      {:noreply, unchanged} =
        AiHandler.handle_skill_event(casting, @target, {:skillused, 28}, 0)

      assert unchanged.target_ref == nil
    end
  end

  describe "lazy think" do
    test "the mob's tick drops its target and reschedules a second later" do
      ticked = tick(lazy_mob_state())

      assert {ticked.target_ref, ticked.skill_state} == {nil, :idle}
      assert Process.read_timer(ticked.ai_timer_ref) <= 1000
    end

    test "a spotted mob takes its due random walk, an unspotted one stays put" do
      now = System.system_time(:millisecond)
      due = %{lazy_mob_state() | target_ref: nil, skill_state: :idle, next_walktime: now - 1}

      spotted = tick(%{due | spotted_by: MapSet.new([42])})
      assert spotted.skill_state == :walk

      unspotted = tick(due)
      assert unspotted.movement_state == :standing
    end

    test "a spotted standing mob checks its idle skills, within the skill interval it does not" do
      now = System.system_time(:millisecond)
      row = %{row() | state: :idle, skill: "MG_SIGHT", skill_id: 10, level: 1, target: :self}
      stub(MobSkillDb, :rows_for, fn 1001 -> [row] end)

      idle = %{
        mob_state()
        | target_ref: nil,
          skill_state: :idle,
          next_walktime: now + 60_000,
          spotted_by: MapSet.new([42]),
          last_skillcheck: now - 1000
      }

      ticked = tick(idle)
      assert %{row: ^row} = ticked.casting
      Process.cancel_timer(ticked.casting.timer_ref)

      recent = tick(%{idle | last_skillcheck: now - 500})
      assert recent.casting == nil
    end

    test "nothing runs within 200 ms of a hard think, or within the skill interval" do
      now = System.system_time(:millisecond)

      assert tick(%{lazy_mob_state() | next_think_at: now - 100}).target_ref == @target
      assert tick(%{lazy_mob_state() | last_skillcheck: now - 500}).target_ref == @target
    end

    test "a player who left the world no longer counts as a spotter" do
      now = System.system_time(:millisecond)
      due = %{lazy_mob_state() | target_ref: nil, skill_state: :idle, next_walktime: now - 1}

      ticked = tick(%{due | spotted_by: MapSet.new([7])})

      assert ticked.spotted_by == MapSet.new()
      assert ticked.movement_state == :standing
    end
  end

  defp row do
    %{
      skill: "MG_FIREBOLT",
      skill_id: 19,
      state: :attack,
      level: 3,
      rate: 10_000,
      cast_time: 50,
      delay: 5_000,
      cancelable: false,
      target: :target,
      condition: %{type: :always},
      emotion: nil
    }
  end

  # A mob past its skill interval, as the lazy think requires.
  defp lazy_mob_state,
    do: %{mob_state() | last_skillcheck: System.system_time(:millisecond) - 1000}

  defp mob_state do
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
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      class: Aesir.ZoneServer.Mmo.MobManagement.MobMode.class([:can_move, :can_attack]),
      modes: [:can_move, :can_attack]
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    now = System.system_time(:millisecond)

    %{
      MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
      | spawn_tick_pending?: false,
        process_pid: self(),
        target_ref: @target,
        skill_state: :berserk,
        next_walktime: now + 60_000,
        last_skillcheck: now,
        last_canmove: now
    }
  end
end
