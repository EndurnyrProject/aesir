defmodule Aesir.ZoneServer.Integration.SkillTargetVisibilityParityTest do
  @moduledoc """
  Real-session coverage for how an area or ground skill re-checks each recipient:
  animated splash neighbours and ground-unit occupants are refused while Hiding
  (unless the skill is TargetHidden) but not while Cloaking, the targeted unit is
  never re-checked, and Storm Gust passes over a frozen occupant. Ki Explosion
  strikes only its target and pushes the enemies around it.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Aesir.ZoneServer.HwProfessorFixture

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @swordman 1
  @wizard 9
  @monk 15
  @high_wizard 4010
  @magnum_break 7
  @napalm_beat 11
  @storm_gust 89
  @heavens_drive 91
  @gravitation 484
  @ki_explosion 1_016
  @full_hp 100_000

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  test "Magnum Break skips a hidden neighbour but strikes a cloaked one" do
    caster = start_caster(@swordman, %{"#{@magnum_break}" => 10})
    plain = start_target({151, 150})
    hidden = start_target({149, 150})
    cloaked = start_target({150, 151})
    conceal(hidden, :sc_hiding)
    conceal(cloaked, :sc_cloaking)

    cast(caster, @magnum_break, 10)

    assert eventually(fn -> hp(plain) < @full_hp and hp(cloaked) < @full_hp end, 8_000)
    assert hp(hidden) == @full_hp
  end

  test "Napalm Beat strikes its target but not a hidden neighbour" do
    caster = start_caster(@wizard, %{"#{@napalm_beat}" => 1})
    primary = start_target({153, 150})
    hidden = start_target({154, 150})
    conceal(hidden, :sc_hiding)

    cast(caster, @napalm_beat, 1, primary.unit_id)

    assert eventually(fn -> hp(primary) < @full_hp end, 8_000)
    assert hp(hidden) == @full_hp
  end

  test "Heaven's Drive reaches a hidden unit" do
    caster = start_caster(@wizard, %{"#{@heavens_drive}" => 1})
    hidden = start_target({153, 150})
    conceal(hidden, :sc_hiding)

    cast_ground(caster, @heavens_drive, 1, {153, 150})

    assert eventually(fn -> hp(hidden) < @full_hp end, 8_000)
  end

  test "Storm Gust passes over hidden and frozen occupants but strikes a cloaked one" do
    caster = start_caster(@wizard, %{"#{@storm_gust}" => 1})
    hidden = start_target({155, 150})
    frozen = start_target({156, 150})
    cloaked = start_target({154, 150})
    conceal(hidden, :sc_hiding)
    :ok = StatusStorage.apply_status(:mob, frozen.unit_id, :sc_freeze)
    conceal(cloaked, :sc_cloaking)

    cast_ground(caster, @storm_gust, 1, {155, 150})

    assert eventually(fn -> hp(cloaked) < @full_hp end, 10_000)
    Process.sleep(1_000)
    assert hp(hidden) == @full_hp
    assert hp(frozen) == @full_hp
  end

  @tag game_mode: :pre_renewal, integration_re: false
  test "classic Gravitation Field slows and strikes a hidden enemy" do
    caster = start_caster(@high_wizard, %{"#{@gravitation}" => 1}, [{717, 1}])
    hidden = start_target({156, 150})
    conceal(hidden, :sc_hiding)

    cast_ground(caster, @gravitation, 1, {155, 150})

    assert eventually(
             fn ->
               StatusStorage.has_status?(:mob, hidden.unit_id, :sc_gravitation) and
                 hp(hidden) < @full_hp
             end,
             10_000
           )
  end

  test "Ki Explosion strikes only its target and pushes the enemy beside it" do
    caster = start_caster(@monk, %{"#{@ki_explosion}" => 1})
    primary = start_target({151, 150}, level: 1, agi: 0)
    neighbour = start_target({152, 150})

    cast(caster, @ki_explosion, 1, primary.unit_id)

    assert eventually(fn -> hp(primary) < @full_hp end, 8_000)
    assert eventually(fn -> get_mob_state(neighbour.pid).x > 152 end)
    assert hp(neighbour) == @full_hp
    assert {get_mob_state(primary.pid).x, get_mob_state(primary.pid).y} == {151, 150}
  end

  defp conceal(mob, status), do: :ok = StatusStorage.apply_status(:mob, mob.unit_id, status)

  defp hp(mob), do: get_mob_state(mob.pid).hp
end
