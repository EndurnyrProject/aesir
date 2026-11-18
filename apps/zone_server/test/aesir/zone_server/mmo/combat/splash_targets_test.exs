defmodule Aesir.ZoneServer.Mmo.Combat.SplashTargetsTest do
  use ExUnit.Case, async: true
  import Mimic
  import Aesir.ZoneServer.Factory

  alias Aesir.TestMob
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!

  @caster_id 1000
  @map_name "prontera"
  @center {150, 150}

  defp build_caster do
    build(:player_state,
      character_id: @caster_id,
      account_id: @caster_id,
      x: 150,
      y: 150,
      map_name: @map_name,
      stats: %{
        combat_stats: %CombatStats{atk: 1, def: 1, hit: 200, flee: 1, perfect_dodge: 1},
        derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
        current_state: %{hp: 100, sp: 50},
        progression: %{base_level: 1, job_level: 1}
      }
    )
  end

  defp build_mob(unit_id, x, y) do
    build(:mob_state,
      instance_id: unit_id,
      mob_data: TestMob.definition(sp: 50, def: 5, mdef: 3),
      map_name: @map_name,
      x: x,
      y: y
    )
  end

  defp stub_ground_unit_footprint do
    caster = build_caster()
    mob = build_mob(2001, 151, 150)

    stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 2 ->
      [{:mob, 2001}, {:player, @caster_id}]
    end)

    stub(UnitRegistry, :get_unit, fn
      :mob, 2001 -> {:ok, {MobState, mob, self()}}
      :player, @caster_id -> {:ok, {PlayerState, caster, self()}}
    end)

    stub(UnitRegistry, :get_player_pid, fn @caster_id -> {:ok, self()} end)

    stub(SpatialIndex, :get_unit_position, fn
      :mob, 2001 -> {:ok, {151, 150, @map_name}}
      :player, @caster_id -> {:ok, {150, 150, @map_name}}
    end)
  end

  test "without hits_caster the caster is excluded from its own ground unit's targets" do
    stub_ground_unit_footprint()

    assert Enum.sort(SplashTargets.select(@map_name, @center, 2, @caster_id)) == [{:mob, 2001}]
  end

  test "with hits_caster: true the caster is included in its own ground unit's targets" do
    stub_ground_unit_footprint()

    assert Enum.sort(SplashTargets.select(@map_name, @center, 2, @caster_id, true)) ==
             [{:mob, 2001}, {:player, @caster_id}]
  end

  test "authorize: replaces the enemy relation, keeping the caster excluded" do
    stub_ground_unit_footprint()
    test_pid = self()

    authorize = fn caster, target ->
      send(test_pid, {:asked, caster.unit_id, target.unit_type})
      false
    end

    assert SplashTargets.select(@map_name, @center, 2, @caster_id, false, authorize: authorize) ==
             []

    assert_received {:asked, @caster_id, :mob}
    refute_received {:asked, @caster_id, :player}

    assert SplashTargets.select(@map_name, @center, 2, @caster_id, false,
             authorize: fn _caster, _target -> true end
           ) == [{:mob, 2001}]
  end
end
