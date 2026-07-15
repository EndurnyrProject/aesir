defmodule Aesir.ZoneServer.Mmo.CombatMagicAttackTest do
  use ExUnit.Case, async: false
  import Mimic
  import Aesir.TestEtsSetup

  @moduletag :capture_log

  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.WzEarthspike
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Sightblaster
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

  setup :setup_ets_tables
  setup :verify_on_exit!

  @caster_id 1000
  @target_id 2001
  @map_name "prontera"
  @center {150, 150}

  defp build_caster do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 1, def: 1, hit: 1, flee: 1, perfect_dodge: 1, matk: 100},
      derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
      progression: %PlayerProgression{base_level: 1, job_level: 1, learned_skills: %{}},
      equipment: %Equipment{}
    }

    %PlayerState{
      character_id: @caster_id,
      account_id: @caster_id,
      x: 150,
      y: 150,
      map_name: @map_name,
      stats: stats
    }
  end

  defp caster_with_band(min, max) do
    caster = build_caster()

    combat_stats =
      Map.merge(caster.stats.combat_stats, %{matk_min: min, matk_max: max, matk: max})

    put_in(caster.stats.combat_stats, combat_stats)
  end

  defp build_mob_state(unit_id, x, y) do
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
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      ai_type: 0,
      modes: [],
      drops: []
    }

    mob_spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: x, y: y, xs: 0, ys: 0}
    }

    %MobState{
      instance_id: unit_id,
      mob_id: 1002,
      mob_data: mob_definition,
      spawn_ref: mob_spawn,
      x: x,
      y: y,
      map_name: @map_name,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      spawned_at: System.system_time(:second),
      aggro_list: %{}
    }
  end

  defp stub_single_target_mob(x \\ 150, y \\ 150) do
    stub(UnitRegistry, :get_unit, fn
      :mob, @target_id -> {:ok, {MobState, build_mob_state(@target_id, x, y), self()}}
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :mob, @target_id -> {:ok, {x, y, @map_name}}
    end)
  end

  defp targetable_cell do
    manager =
      start_supervised!(
        {Manager,
         name: nil,
         schedule_tick: fn _pid, _interval -> :ok end,
         unit_available?: fn _unit_type, _unit_id, _map_name -> true end}
      )

    :ok =
      Manager.register(
        manager,
        %Group{
          group_id: 1,
          skill_id: 0,
          skill_name: :fixture,
          level: 1,
          caster_id: @caster_id,
          caster_type: :player,
          map_name: @map_name,
          center: @center,
          cells: [],
          next_tick_at: 0,
          expires_at: 1_000_000,
          interval: 1_000,
          visible?: false,
          state: %{}
        }
      )

    {:ok, cell} =
      Manager.create_cell(manager, 1, %{
        x: 151,
        y: 150,
        hp: 20,
        max_hp: 20,
        flags: [:targetable]
      })

    {manager, cell}
  end

  describe "execute_magic_attack/3" do
    test "damages a targetable skill-unit cell through its manager" do
      caster = build_caster()
      {_manager, cell} = targetable_cell()

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _attacker, _target, _opts ->
        {:ok, %{damage: 10, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

      assert :ok =
               Combat.execute_magic_attack(caster, cell.cell_id,
                 skill_id: 19,
                 skill_level: 1,
                 skill_ratio: 100,
                 element: :fire
               )

      assert %{hp: 10} = Storage.get_cell(cell.cell_id)
    end

    test "does not broadcast when a targetable skill-unit cell disappears before damage" do
      caster = build_caster()
      {manager, cell} = targetable_cell()

      Mimic.copy(Manager)

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _attacker, _target, _opts ->
        {:ok, %{damage: 10, is_critical: false}}
      end)

      expect(Manager, :damage_targetable_cell, fn ^manager, cell_id, 10, {:player, @caster_id} ->
        assert cell_id == cell.cell_id
        {:error, :not_found}
      end)

      reject(&Broadcast.to_in_range/5)

      assert {:error, :not_found} =
               Combat.execute_magic_attack(caster, cell.cell_id,
                 skill_id: 19,
                 skill_level: 1,
                 skill_ratio: 100,
                 element: :fire
               )
    end

    test "applies explicit magic damage to a targetable skill-unit cell" do
      caster = build_caster()
      {_manager, cell} = targetable_cell()

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

      assert :ok =
               Combat.execute_magic_damage(caster, cell.cell_id, 10,
                 skill_id: 28,
                 skill_level: 1,
                 element: :neutral
               )

      assert %{hp: 10} = Storage.get_cell(cell.cell_id)
    end

    test "routes status-effect magic damage to a targetable skill-unit cell" do
      {_manager, cell} = targetable_cell()

      assert :ok = Combat.deal_damage(cell.cell_id, 10, :neutral)
      assert %{hp: 10} = Storage.get_cell(cell.cell_id)
    end

    test "Sight Blaster contact damages a targetable skill-unit cell" do
      caster = build_caster()
      {_manager, cell} = targetable_cell()
      cell_id = cell.cell_id

      :ok = UnitRegistry.register_unit(:player, @caster_id, PlayerState, caster, self())
      :ok = SpatialIndex.add_unit(:player, @caster_id, caster.x, caster.y, caster.map_name)

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _attacker, _target, _opts ->
        {:ok, %{damage: 10, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      expect(Combat, :knockback, fn :skill_unit, ^cell_id, 150, 150, 3 -> :ok end)

      assert :remove =
               Sightblaster.on_contact(
                 {:player, @caster_id},
                 %{val1: 1},
                 {:skill_unit, cell_id},
                 %{}
               )

      assert %{hp: 10} = Storage.get_cell(cell.cell_id)
    end

    test "rejects a dead mob before calculating or applying magic damage" do
      caster = build_caster()
      dead_mob = %{build_mob_state(@target_id, 150, 150) | hp: 0}

      stub(UnitRegistry, :get_unit, fn
        :mob, @target_id -> {:ok, {MobState, dead_mob, self()}}
      end)

      stub(SpatialIndex, :get_unit_position, fn
        :mob, @target_id -> {:ok, {150, 150, @map_name}}
      end)

      reject(&MagicDamageCalculator.calculate_magic_damage/3)
      reject(&Broadcast.to_in_range/5)
      reject(&MobSession.apply_damage/3)

      assert {:error, :target_dead} =
               WzEarthspike.cast(caster, {:unit, @target_id}, 1, WzEarthspike.definition())
    end

    test "Earth Spike level 1 damages a live mob through the magic pipeline" do
      caster = build_caster()
      test_pid = self()
      stub_single_target_mob()

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _a, _t, opts ->
        assert opts[:element] == :earth
        assert opts[:skill_ratio] == 200
        {:ok, %{damage: 30, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn @map_name, 150, 150, _range, %SkillDamage{} = packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      assert {:ok, ^caster} =
               WzEarthspike.cast(caster, {:unit, @target_id}, 1, WzEarthspike.definition())

      assert_received {:packet, %SkillDamage{damage: 30, div: 1, skill_id: 90, level: 1}}
      assert_received {:damage, 30}
    end

    test "each of a multi-hit cast rolls magic damage independently and sums" do
      caster = caster_with_band(10, 1000)
      test_pid = self()
      stub_single_target_mob()

      # The MATK roll now lives inside the calculator (per call); a stubbed
      # calculator just confirms each hit is a separate calculate call summed.
      stub(MagicDamageCalculator, :calculate_magic_damage, fn _a, _t, _opts ->
        {:ok, %{damage: 30, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn @map_name, 150, 150, _range, %SkillDamage{} = packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      assert :ok =
               Combat.execute_magic_attack(caster, @target_id,
                 skill_id: 19,
                 skill_level: 3,
                 skill_ratio: 100,
                 element: :fire,
                 hit_count: 3
               )

      assert_received {:packet, %SkillDamage{damage: 90, div: 3}}
      assert_received {:damage, 90}
    end

    test "applies direct magic damage to a live player target" do
      caster = build_caster()
      target_player = self()
      test_pid = self()

      stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:error, :not_found} end)
      stub(UnitRegistry, :get_player_pid, fn @target_id -> {:ok, target_player} end)
      stub(PlayerSession, :get_current_stats, fn ^target_player -> build_caster().stats end)

      stub(PlayerSession, :get_state, fn ^target_player ->
        %{game_state: %{build_caster() | character_id: @target_id, x: 150, y: 150}}
      end)

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _a, _t, _opts ->
        {:ok, %{damage: 30, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn @map_name, 150, 150, _range, %SkillDamage{} = packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      stub(PlayerSession, :apply_damage, fn ^target_player, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      assert {:ok, ^caster} =
               WzEarthspike.cast(caster, {:unit, @target_id}, 5, WzEarthspike.definition())

      assert_received {:packet, %SkillDamage{damage: 150, div: 5, skill_id: 90, level: 5}}
      assert_received {:damage, 150}
    end

    test "rejects direct magic damage against a player in the same party" do
      caster = %{build_caster() | party_id: 10}
      target_player = self()
      target = %{build_caster() | character_id: @target_id, party_id: 10}

      stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:error, :not_found} end)
      stub(UnitRegistry, :get_player_pid, fn @target_id -> {:ok, target_player} end)
      stub(PlayerSession, :get_current_stats, fn ^target_player -> target.stats end)
      stub(PlayerSession, :get_state, fn ^target_player -> %{game_state: target} end)

      reject(&MagicDamageCalculator.calculate_magic_damage/3)
      reject(&Broadcast.to_in_range/5)
      reject(&PlayerSession.apply_damage/3)

      assert {:error, :invalid_target} =
               Combat.execute_magic_attack(caster, @target_id,
                 skill_id: 90,
                 skill_level: 1,
                 skill_ratio: 200,
                 element: :earth,
                 hit_count: 1
               )
    end

    test "returns an error when the target is out of range" do
      caster = build_caster()
      stub_single_target_mob(170, 170)

      assert {:error, :target_out_of_range} =
               Combat.execute_magic_attack(caster, @target_id,
                 skill_id: 19,
                 skill_level: 1,
                 skill_ratio: 100,
                 element: :fire,
                 hit_count: 1
               )
    end
  end

  describe "execute_magic_splash/4" do
    test "line-of-sight splash uses rAthena's diagonal integer traversal" do
      caster = build_caster()
      visible_id = 2001
      blocked_id = 2002

      Mimic.copy(Cell)
      stub(Cell, :blocks_projectiles?, fn @map_name, x, y -> {x, y} == {151, 150} end)

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 6 ->
        [{:mob, visible_id}, {:mob, blocked_id}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, ^visible_id ->
          {:ok, {MobState, build_mob_state(visible_id, 150, 153), self()}}

        :mob, ^blocked_id ->
          {:ok, {MobState, build_mob_state(blocked_id, 153, 152), self()}}
      end)

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _attacker, defender, _opts ->
        assert defender.unit_id == visible_id
        {:ok, %{damage: 40, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      expect(MobSession, :apply_damage, fn _pid, 40, @caster_id -> :ok end)

      assert [{:mob, ^visible_id}] =
               Combat.execute_magic_splash(caster, @center, 3,
                 skill_id: 88,
                 skill_level: 1,
                 skill_ratio: 110,
                 element: :water,
                 line_of_sight: true
               )
    end

    test "preserves the spatial index unit type when mob and player ids collide" do
      caster = build_caster()
      target = %{build_caster() | character_id: @target_id, x: 151}
      target_pid = self()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 4 ->
        [{:player, @target_id}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, @target_id ->
          {:ok, {MobState, build_mob_state(@target_id, 151, 150), self()}}
      end)

      stub(UnitRegistry, :get_player_pid, fn @target_id -> {:ok, target_pid} end)
      stub(PlayerSession, :get_current_stats, fn ^target_pid -> target.stats end)
      stub(PlayerSession, :get_state, fn ^target_pid -> %{game_state: target} end)

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _attacker, defender, _opts ->
        assert defender.unit_type == :player
        {:ok, %{damage: 40, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      expect(PlayerSession, :apply_damage, fn ^target_pid, 40, @caster_id -> :ok end)
      reject(&MobSession.apply_damage/3)

      assert [{:player, @target_id}] =
               Combat.execute_magic_splash(caster, @center, 2,
                 skill_id: 88,
                 skill_level: 1,
                 skill_ratio: 110,
                 element: :water
               )
    end

    test "does not exclude a mob whose numeric id matches the player caster" do
      caster = build_caster()
      target_pid = self()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 4 ->
        [{:mob, @caster_id}]
      end)

      stub(UnitRegistry, :get_unit, fn :mob, @caster_id ->
        {:ok, {MobState, build_mob_state(@caster_id, 151, 150), target_pid}}
      end)

      stub(SpatialIndex, :get_unit_position, fn :mob, @caster_id ->
        {:ok, {151, 150, @map_name}}
      end)

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _attacker, defender, _opts ->
        assert defender.unit_type == :mob
        {:ok, %{damage: 40, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      expect(MobSession, :apply_damage, fn ^target_pid, 40, @caster_id -> :ok end)

      assert [{:mob, @caster_id}] =
               Combat.execute_magic_splash(caster, @center, 2,
                 skill_id: 88,
                 skill_level: 1,
                 skill_ratio: 110,
                 element: :water
               )
    end

    test "includes an enemy player but excludes self and same-party players" do
      caster = %{build_caster() | party_id: 10}
      ally_id = 2002
      enemy_id = 2003
      self_pid = spawn(fn -> Process.sleep(:infinity) end)
      ally_pid = spawn(fn -> Process.sleep(:infinity) end)
      enemy_pid = spawn(fn -> Process.sleep(:infinity) end)

      on_exit(fn ->
        Enum.each([self_pid, ally_pid, enemy_pid], &Process.exit(&1, :kill))
      end)

      states = %{
        self_pid => caster,
        ally_pid => %{build_caster() | character_id: ally_id, party_id: 10, x: 151},
        enemy_pid => %{build_caster() | character_id: enemy_id, party_id: 0, x: 152}
      }

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 4 ->
        [{:player, @caster_id}, {:player, ally_id}, {:player, enemy_id}]
      end)

      stub(UnitRegistry, :get_unit, fn :mob, id when id in [@caster_id, ally_id, enemy_id] ->
        {:error, :not_found}
      end)

      stub(UnitRegistry, :get_player_pid, fn
        @caster_id -> {:ok, self_pid}
        ^ally_id -> {:ok, ally_pid}
        ^enemy_id -> {:ok, enemy_pid}
      end)

      stub(PlayerSession, :get_current_stats, fn pid -> states[pid].stats end)
      stub(PlayerSession, :get_state, fn pid -> %{game_state: states[pid]} end)

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _attacker, target, _opts ->
        assert target.unit_id == enemy_id
        {:ok, %{damage: 40, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

      expect(PlayerSession, :apply_damage, fn ^enemy_pid, 40, @caster_id -> :ok end)

      assert [{:player, ^enemy_id}] =
               Combat.execute_magic_splash(caster, @center, 2,
                 skill_id: 90,
                 skill_level: 1,
                 skill_ratio: 200,
                 element: :earth
               )
    end

    test "hits each target for full damage without :split" do
      caster = build_caster()
      test_pid = self()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 4 ->
        [{:mob, 2001}, {:mob, 2002}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 2001 -> {:ok, {MobState, build_mob_state(2001, 150, 150), self()}}
        :mob, 2002 -> {:ok, {MobState, build_mob_state(2002, 151, 150), self()}}
      end)

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _a, _t, _opts ->
        {:ok, %{damage: 40, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, _p -> :ok end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      hits =
        Combat.execute_magic_splash(caster, @center, 2,
          skill_id: 17,
          skill_level: 5,
          skill_ratio: 240,
          element: :fire
        )

      assert Enum.sort(hits) == [{:mob, 2001}, {:mob, 2002}]
      assert_received {:damage, 40}
      assert_received {:damage, 40}
    end

    test "divides total damage across targets with :split" do
      caster = build_caster()
      test_pid = self()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 2 ->
        [{:mob, 2001}, {:mob, 2002}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 2001 -> {:ok, {MobState, build_mob_state(2001, 150, 150), self()}}
        :mob, 2002 -> {:ok, {MobState, build_mob_state(2002, 151, 150), self()}}
      end)

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _a, _t, _opts ->
        {:ok, %{damage: 100, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, _p -> :ok end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      hits =
        Combat.execute_magic_splash(caster, @center, 1,
          skill_id: 11,
          skill_level: 1,
          skill_ratio: 80,
          element: :ghost,
          split: true
        )

      assert Enum.sort(hits) == [{:mob, 2001}, {:mob, 2002}]
      assert_received {:damage, 50}
      assert_received {:damage, 50}
    end

    test "each splash target rolls its magic damage independently (no shared roll)" do
      # Real calculator (not stubbed) with a wide MATK band; over several casts
      # the per-target damages must vary, proving each target rolls its own MATK.
      caster = caster_with_band(1, 2000)
      test_pid = self()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 4 ->
        [{:mob, 2001}, {:mob, 2002}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 2001 -> {:ok, {MobState, build_mob_state(2001, 150, 150), self()}}
        :mob, 2002 -> {:ok, {MobState, build_mob_state(2002, 151, 150), self()}}
      end)

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, _p -> :ok end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      for _ <- 1..6 do
        Combat.execute_magic_splash(caster, @center, 2,
          skill_id: 17,
          skill_level: 5,
          skill_ratio: 240,
          element: :fire
        )
      end

      damages = drain_damages()

      assert length(damages) == 12
      assert Enum.all?(damages, &(&1 >= 1))
      assert length(Enum.uniq(damages)) > 1
    end

    test "a degenerate band (min == max) gives deterministic splash damage" do
      caster = caster_with_band(50, 50)
      test_pid = self()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 4 ->
        [{:mob, 2001}, {:mob, 2002}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 2001 -> {:ok, {MobState, build_mob_state(2001, 150, 150), self()}}
        :mob, 2002 -> {:ok, {MobState, build_mob_state(2002, 151, 150), self()}}
      end)

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, _p -> :ok end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      for _ <- 1..4 do
        Combat.execute_magic_splash(caster, @center, 2,
          skill_id: 17,
          skill_level: 5,
          skill_ratio: 240,
          element: :fire
        )
      end

      assert [_one] = drain_damages() |> Enum.uniq()
    end
  end

  defp drain_damages(acc \\ []) do
    receive do
      {:damage, damage} -> drain_damages([damage | acc])
    after
      0 -> acc
    end
  end
end
