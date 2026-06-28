defmodule Aesir.ZoneServer.Mmo.CombatMagicAttackTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
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

  describe "execute_magic_attack/3" do
    test "applies hit_count magic hits, summing damage into one packet with div = hits" do
      caster = build_caster()
      test_pid = self()
      stub_single_target_mob()

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _a, _t, opts ->
        assert opts[:element] == :fire
        assert opts[:skill_ratio] == 100
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

      assert_received {:packet, %SkillDamage{damage: 90, div: 3, skill_id: 19, level: 3}}
      assert_received {:damage, 90}
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

    test "returns {:error, :pvp_not_implemented} for a player target" do
      caster = build_caster()
      target_player = spawn(fn -> Process.sleep(:infinity) end)

      stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:error, :not_found} end)
      stub(UnitRegistry, :get_player_pid, fn @target_id -> {:ok, target_player} end)
      stub(PlayerSession, :get_current_stats, fn ^target_player -> build_caster().stats end)

      stub(PlayerSession, :get_state, fn ^target_player ->
        %{game_state: %{build_caster() | character_id: @target_id, x: 150, y: 150}}
      end)

      assert {:error, :pvp_not_implemented} =
               Combat.execute_magic_attack(caster, @target_id,
                 skill_id: 19,
                 skill_level: 1,
                 skill_ratio: 100,
                 element: :fire,
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

      assert Enum.sort(hits) == [2001, 2002]
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

      assert Enum.sort(hits) == [2001, 2002]
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
