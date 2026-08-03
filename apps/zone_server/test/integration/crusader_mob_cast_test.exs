defmodule Aesir.ZoneServer.Integration.CrusaderMobCastTest do
  @moduledoc """
  Proves Crusader mob casting behaves correctly beyond the sweep's clean-result
  check:

    * `CR_GRANDCROSS` (Grand Cross) damages nearby players through its ground
      field but never damages the mob caster itself - the `on_interval` self
      exclusion for mob casters, unlike a player caster's halved self-damage.
    * `CR_SHIELDCHARGE` (Shield Charge) hits its target through the plain-batk
      fallback (`damage_base: :shield`) with no shield equipped - a mob caster
      carries no equipment at all.
    * `CR_AUTOGUARD` (Guard) toggles `sc_autoguard` onto the mob caster with no
      shield gate.

  `CR_DEVOTION` is not exercised here: it is denylisted (party/devotion
  semantics are player-only) so the sweep only asserts the denylist reason.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.MobSkill.Denylist
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Catalog, as: SkillCatalog
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrDevotion
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @map "prontera"

  setup do
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
    :ok
  end

  test "a mob casting Grand Cross damages a nearby player but never itself" do
    target =
      start_player_session(character: player_character(9_201, {151, 150}), position: {151, 150})

    mob = start_mob_session(unit_id: 9_301, map_name: @map, position: {150, 150})

    mob_hp = current_mob_hp(mob.pid)
    target_hp = current_hp(target.pid)

    caster = %{mob_state(mob) | target_ref: {:player, target.character.id}}

    assert :ok = Executor.execute(caster, grandcross_row())

    assert eventually(fn -> current_hp(target.pid) < target_hp end)

    Process.sleep(200)
    assert current_mob_hp(mob.pid) == mob_hp
  end

  test "a mob casting Shield Charge damages its target through the plain-batk fallback" do
    target =
      start_player_session(character: player_character(9_202, {151, 150}), position: {151, 150})

    mob = start_mob_session(unit_id: 9_302, map_name: @map, position: {150, 150})

    target_hp = current_hp(target.pid)

    caster = %{mob_state(mob) | target_ref: {:player, target.character.id}}

    assert :ok = Executor.execute(caster, shieldcharge_row())

    assert eventually(fn -> current_hp(target.pid) < target_hp end)
  end

  test "a mob casting Guard toggles sc_autoguard on with no shield gate" do
    mob = start_mob_session(unit_id: 9_303, map_name: @map, position: {150, 150})

    caster = mob_state(mob)

    assert :ok = Executor.execute(caster, autoguard_row())

    assert eventually(fn -> StatusStorage.has_status?(:mob, 9_303, :sc_autoguard) end)
  end

  test "Devotion is denied for mob casters with a stated reason" do
    assert Denylist.denied?(255)
    assert Denylist.reason_for(255) =~ "player-only"

    mob = start_mob_session(unit_id: 9_304, map_name: @map, position: {150, 150})

    assert {:error, :mob_cannot_devote} =
             CrDevotion.validate(mob_state(mob), {:unit, 9_304}, 1, definition())
  end

  defp definition do
    {:ok, definition} = SkillCatalog.by_id(255)
    definition
  end

  defp mob_state(mob), do: get_mob_state(mob.pid)

  defp current_hp(pid), do: get_player_state(pid).stats.current_state.hp

  defp current_mob_hp(pid), do: get_mob_state(pid).hp

  defp grandcross_row, do: %{skill: "CR_GRANDCROSS", skill_id: 254, target: :self, level: 1}

  defp shieldcharge_row,
    do: %{skill: "CR_SHIELDCHARGE", skill_id: 250, target: :target, level: 1}

  defp autoguard_row, do: %{skill: "CR_AUTOGUARD", skill_id: 249, target: :self, level: 1}

  defp player_character(id, {x, y}) do
    %Character{
      id: id,
      account_id: id,
      name: "Target#{id}",
      char_num: 0,
      class: 0,
      base_level: 40,
      job_level: 1,
      str: 20,
      agi: 20,
      vit: 20,
      int: 10,
      dex: 20,
      luk: 10,
      hp: 5_000,
      max_hp: 5_000,
      sp: 50,
      max_sp: 50,
      last_map: @map,
      last_x: x,
      last_y: y,
      save_map: @map,
      save_x: 150,
      save_y: 150,
      hair: 1,
      hair_color: 1,
      clothes_color: 0,
      online: true
    }
  end
end
