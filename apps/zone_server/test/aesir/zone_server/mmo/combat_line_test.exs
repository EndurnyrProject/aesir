defmodule Aesir.ZoneServer.Mmo.CombatLineTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 1000
  @map_name "prontera"
  @caster_pos {150, 150}

  defp build_caster do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 1, def: 1, hit: 200, flee: 1, perfect_dodge: 1},
      derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
      progression: %PlayerProgression{base_level: 1, job_level: 1, learned_skills: %{}},
      equipment: %Equipment{}
    }

    {sx, sy} = @caster_pos

    %PlayerState{
      character_id: @caster_id,
      account_id: @caster_id,
      x: sx,
      y: sy,
      map_name: @map_name,
      stats: stats
    }
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

  # Stubs the position/registry lookups shared by every scenario: `mobs` is a
  # `[{unit_id, x, y}]` list of live mobs the spatial index and registry know
  # about at the given coordinates.
  defp stub_mobs(mobs) do
    mob_pid = self()

    positions = Map.new(mobs, fn {id, x, y} -> {id, {x, y}} end)

    stub(SpatialIndex, :get_unit_position, fn
      :player, _id ->
        {:error, :not_found}

      :mob, id ->
        {x, y} = Map.fetch!(positions, id)
        {:ok, {x, y, @map_name}}
    end)

    stub(UnitRegistry, :get_unit, fn :mob, id ->
      {x, y} = Map.fetch!(positions, id)
      {:ok, {MobState, build_mob_state(id, x, y), mob_pid}}
    end)
  end

  defp stub_damage_pipeline do
    stub(DamageCalculator, :calculate_damage, fn _attacker, _target, _opts ->
      {:ok, %{damage: 50, is_critical: false}}
    end)

    stub(PacketFactory, :build_skill_damage_packet, fn _a, _t, _id, _lvl, _res -> :packet end)

    test_pid = self()

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, :packet ->
      send(test_pid, :broadcast)
      :ok
    end)

    stub(MobSession, :apply_damage, fn _pid, 50, @caster_id ->
      send(test_pid, :apply_damage)
      :ok
    end)
  end

  test "hits the target plus a mob on a diagonal line, skipping one standing off the line" do
    caster = build_caster()
    # Diagonal line from (150, 150) to (153, 153): (151, 151), (152, 152) sit
    # between the endpoints.
    stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 6 ->
      [{:mob, 3000}, {:mob, 2001}, {:mob, 2002}]
    end)

    stub_mobs([{3000, 153, 153}, {2001, 151, 151}, {2002, 152, 150}])
    stub_damage_pipeline()

    hits =
      Combat.execute_line_attack(caster, 3000,
        skill_id: 58,
        skill_level: 5,
        skill_ratio: 200,
        skip_crit: true
      )

    assert Enum.sort(hits) == [2001, 3000]
    refute 2002 in hits
    assert_received :broadcast
    assert_received :apply_damage
    assert_received :broadcast
    assert_received :apply_damage
  end

  test "hits every mob on a straight horizontal line, skipping one standing off the line" do
    caster = build_caster()

    stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 3 ->
      [{:mob, 3000}, {:mob, 2001}, {:mob, 2002}]
    end)

    stub_mobs([{3000, 153, 150}, {2001, 151, 150}, {2002, 151, 151}])
    stub_damage_pipeline()

    hits =
      Combat.execute_line_attack(caster, 3000,
        skill_id: 58,
        skill_level: 1,
        skill_ratio: 120,
        skip_crit: true
      )

    assert Enum.sort(hits) == [2001, 3000]
    refute 2002 in hits
  end

  test "skips a dead mob standing on the line" do
    caster = build_caster()

    stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 3 ->
      [{:mob, 3000}]
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :player, _id -> {:error, :not_found}
      :mob, 3000 -> {:ok, {153, 150, @map_name}}
    end)

    dead_mob = %{build_mob_state(3000, 153, 150) | hp: 0}
    stub(UnitRegistry, :get_unit, fn :mob, 3000 -> {:ok, {MobState, dead_mob, self()}} end)

    hits =
      Combat.execute_line_attack(caster, 3000,
        skill_id: 58,
        skill_level: 1,
        skill_ratio: 120,
        skip_crit: true
      )

    assert hits == []
  end
end
