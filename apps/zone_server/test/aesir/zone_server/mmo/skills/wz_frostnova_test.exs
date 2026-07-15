defmodule Aesir.ZoneServer.Mmo.Skills.WzFrostnovaTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skills.WzFrostnova
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  describe "definition/0" do
    test "matches the Renewal Frost Nova table at levels 1 and 10" do
      definition = WzFrostnova.definition()

      assert definition.id == 88
      assert definition.name == :wz_frostnova
      assert definition.max_level == 10
      assert definition.target_type == :self
      assert definition.damage_type == :damage
      assert definition.damage_kind == :magic
      assert definition.element == :water
      assert definition.splash_radius == 3
      assert definition.hit_count == 1
      assert definition.cast_time == [640, 640, 576, 576, 512, 512, 448, 448, 384, 384]
      assert definition.fixed_cast_time == [160, 160, 144, 144, 128, 128, 112, 112, 96, 96]
      assert definition.after_cast_delay == List.duplicate(200, 10)

      assert definition.duration == [
               1_500,
               3_000,
               4_500,
               6_000,
               7_500,
               9_000,
               10_500,
               12_000,
               13_500,
               15_000
             ]

      assert definition.sp_cost == [45, 43, 41, 39, 37, 35, 33, 31, 29, 27]
    end

    test "radius 3 includes the inner cells and 7x7 edge but excludes radius 4" do
      cells = Layout.square({150, 150}, WzFrostnova.definition().splash_radius)

      assert length(cells) == 49
      assert {150, 151} in cells
      assert {147, 147} in cells
      assert {153, 153} in cells
      refute {146, 150} in cells
      refute {150, 154} in cells
    end
  end

  describe "cast/4" do
    test "level 1 immediately attacks the caster-centered radius at 110% Water MATK" do
      caster = %{character_id: 1_000, x: 150, y: 150}
      definition = WzFrostnova.definition()

      expect(Combat, :execute_magic_splash, fn ^caster, {150, 150}, 3, opts ->
        assert opts[:skill_id] == 88
        assert opts[:skill_level] == 1
        assert opts[:skill_ratio] == 110
        assert opts[:element] == :water
        assert opts[:split] == false
        assert opts[:line_of_sight] == true
        []
      end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster} = WzFrostnova.cast(caster, :self, 1, definition)
    end

    test "level 10 independently attempts a 15-second Freeze on hit mobs and players" do
      caster = %{character_id: 1_000, x: 150, y: 150}
      definition = WzFrostnova.definition()
      resistance_roll = fn rate -> rate >= 83 end

      expect(Combat, :execute_magic_splash, fn ^caster, {150, 150}, 3, opts ->
        assert opts[:skill_ratio] == 200
        [{:mob, 2_001}, {:player, 2_002}]
      end)

      expect(StatusInterpreter, :apply_status, 2, fn unit_type, target_id, :sc_freeze, params ->
        assert {unit_type, target_id} in [{:mob, 2_001}, {:player, 2_002}]
        assert params[:duration] == 15_000
        assert params[:success_rate] == 83
        assert params[:resistance_roll].(83)
        :ok
      end)

      assert {:ok, ^caster} =
               WzFrostnova.cast(caster, :self, 10, definition, resistance_roll)
    end

    test "level 1 Freeze chance accepts the exact 38 boundary and lasts 1.5 seconds" do
      caster = %{character_id: 1_000, x: 150, y: 150}
      definition = WzFrostnova.definition()
      resistance_roll = fn rate -> 38 <= rate end

      stub(Combat, :execute_magic_splash, fn _, _, _, _ -> [{:mob, 2_001}] end)

      expect(StatusInterpreter, :apply_status, fn :mob, 2_001, :sc_freeze, params ->
        assert params[:duration] == 1_500
        assert params[:success_rate] == 38
        assert params[:resistance_roll].(params[:success_rate])
        :ok
      end)

      assert {:ok, ^caster} =
               WzFrostnova.cast(caster, :self, 1, definition, resistance_roll)
    end

    test "level 1 Freeze chance rejects the adjacent 39 boundary" do
      caster = %{character_id: 1_000, x: 150, y: 150}
      definition = WzFrostnova.definition()
      resistance_roll = fn rate -> 39 <= rate end

      stub(Combat, :execute_magic_splash, fn _, _, _, _ -> [{:mob, 2_001}] end)

      expect(StatusInterpreter, :apply_status, fn :mob, 2_001, :sc_freeze, params ->
        refute params[:resistance_roll].(params[:success_rate])
        {:error, :resisted}
      end)

      assert {:ok, ^caster} =
               WzFrostnova.cast(caster, :self, 1, definition, resistance_roll)
    end

    test "resisted and immune Freeze attempts do not fail the damaging cast" do
      caster = %{character_id: 1_000, x: 150, y: 150}
      definition = WzFrostnova.definition()

      stub(Combat, :execute_magic_splash, fn _, _, _, _ ->
        [{:mob, 2_001}, {:player, 2_002}]
      end)

      expect(StatusInterpreter, :apply_status, 2, fn
        :mob, 2_001, :sc_freeze, _params -> {:error, :resisted}
        :player, 2_002, :sc_freeze, _params -> {:error, :immune}
      end)

      assert {:ok, ^caster} = WzFrostnova.cast(caster, :self, 10, definition)
    end
  end

  describe "real splash integration" do
    test "hits living enemies through the 7x7 boundary while excluding caster, allies, dead, outside and blocked units" do
      caster = %{build_player(1_000, 150, 150) | party_id: 10, guild_id: 20}
      inner_id = 2_001
      boundary_id = 2_002
      outside_id = 2_003
      dead_id = 2_004
      blocked_id = 2_005
      ally_id = 3_001
      enemy_id = 3_002
      test_pid = self()

      mobs = %{
        inner_id => build_mob(inner_id, 149, 150),
        boundary_id => build_mob(boundary_id, 150, 153),
        outside_id => build_mob(outside_id, 154, 150),
        dead_id => %{build_mob(dead_id, 150, 149) | hp: 0, is_dead: true},
        blocked_id => build_mob(blocked_id, 153, 150)
      }

      players = %{
        ally_id => %{build_player(ally_id, 150, 151) | party_id: 10},
        enemy_id => build_player(enemy_id, 148, 150)
      }

      pids =
        (Map.keys(mobs) ++ Map.keys(players))
        |> Map.new(fn id -> {id, spawn(fn -> Process.sleep(:infinity) end)} end)

      ids_by_pid = Map.new(pids, fn {id, pid} -> {pid, id} end)

      on_exit(fn -> Enum.each(pids, fn {_id, pid} -> Process.exit(pid, :kill) end) end)

      Mimic.copy(Cell)
      stub(Cell, :blocks_projectiles?, fn "prontera", x, y -> {x, y} == {151, 150} end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, 6 ->
        [
          {:player, 1_000},
          {:mob, inner_id},
          {:mob, boundary_id},
          {:mob, outside_id},
          {:mob, dead_id},
          {:mob, blocked_id},
          {:player, ally_id},
          {:player, enemy_id}
        ]
      end)

      stub(UnitRegistry, :get_unit, fn :mob, id ->
        {:ok, {MobState, Map.fetch!(mobs, id), Map.fetch!(pids, id)}}
      end)

      stub(SpatialIndex, :get_unit_position, fn :mob, id ->
        mob = Map.fetch!(mobs, id)
        {:ok, {mob.x, mob.y, mob.map_name}}
      end)

      stub(UnitRegistry, :get_player_pid, fn id -> {:ok, Map.fetch!(pids, id)} end)
      stub(PlayerSession, :get_current_stats, fn pid -> players[ids_by_pid[pid]].stats end)

      stub(PlayerSession, :get_state, fn pid ->
        %{game_state: Map.fetch!(players, ids_by_pid[pid])}
      end)

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _attacker, defender, opts ->
        assert defender.unit_id in [inner_id, boundary_id, enemy_id]
        assert opts[:skill_ratio] == 110
        assert opts[:element] == :water
        {:ok, %{damage: 40, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

      stub(MobSession, :apply_damage, fn pid, 40, 1_000 ->
        id = Map.fetch!(ids_by_pid, pid)
        send(test_pid, {:damage, {:mob, id}})
        :ok
      end)

      stub(PlayerSession, :apply_damage, fn pid, 40, 1_000 ->
        id = Map.fetch!(ids_by_pid, pid)
        send(test_pid, {:damage, {:player, id}})
        :ok
      end)

      resistance_roll = fn rate -> rate >= 38 end

      stub(StatusInterpreter, :apply_status, fn unit_type, id, :sc_freeze, params ->
        assert params[:duration] == 1_500
        assert params[:success_rate] == 38
        assert params[:resistance_roll].(38)
        send(test_pid, {:freeze, {unit_type, id}})
        :ok
      end)

      assert {:ok, ^caster} =
               WzFrostnova.cast(
                 caster,
                 :self,
                 1,
                 WzFrostnova.definition(),
                 resistance_roll
               )

      expected = [{:mob, inner_id}, {:mob, boundary_id}, {:player, enemy_id}]

      Enum.each(expected, fn target ->
        assert_received {:damage, ^target}
        assert_received {:freeze, ^target}
      end)

      refute_received {:damage, _target}
      refute_received {:freeze, _target}
    end
  end

  defp build_player(id, x, y) do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 1, def: 1, hit: 1, flee: 1, perfect_dodge: 1, matk: 100},
      derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
      progression: %PlayerProgression{base_level: 1, job_level: 1, learned_skills: %{}},
      equipment: %Equipment{}
    }

    %PlayerState{
      character_id: id,
      account_id: id,
      x: x,
      y: y,
      map_name: "prontera",
      stats: stats
    }
  end

  defp build_mob(id, x, y) do
    mob_definition = %MobDefinition{
      id: 1002,
      aegis_name: "TEST_MOB",
      name: "TestMob",
      level: 1,
      hp: 100,
      sp: 50,
      base_exp: 10,
      job_exp: 5,
      atk: 10,
      matk: 0,
      def: 5,
      mdef: 3,
      stats: %{str: 10, agi: 10, vit: 10, int: 5, dex: 10, luk: 5},
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      ai_type: 0,
      modes: [],
      drops: []
    }

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: x, y: y, xs: 0, ys: 0}
    }

    %MobState{
      instance_id: id,
      mob_id: 1002,
      mob_data: mob_definition,
      spawn_ref: spawn,
      x: x,
      y: y,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      spawned_at: System.system_time(:second),
      aggro_list: %{}
    }
  end
end
