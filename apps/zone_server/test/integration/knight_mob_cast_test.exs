defmodule Aesir.ZoneServer.Integration.KnightMobCastTest do
  @moduledoc """
  Proves three Knight skills the sweep only checks for a clean, non-crashing
  result actually do the right thing for a mob caster:

    * `KN_TWOHANDQUICKEN` (Two-Hand Quicken) always buffs the caster itself,
      even through the anomalous `mob_skills.yml` row that records this
      self-buff as `target: target` rather than `target: self` - the
      `{:unit, _id}` cast/4 clause ignores the resolved id and buffs whoever
      cast it, never the target that happened to be recorded. The same row
      also carries `level: 30`, past the 10-entry player `duration` array
      (`Enum.at/2` returns `nil` at index 29); unlike `WZ_METEOR`/
      `WZ_VERMILION`'s equivalent out-of-range index (which crash and are
      uncastable by mobs), Two-Hand Quicken degrades gracefully because
      `StatusInterpreter.apply_status/4` falls back to `definition.duration`
      (unset here) and then a hardcoded 10 000 ms - this test locks in that
      fallback rather than a crash.
    * `KN_SPEARSTAB` (Spear Stab) damages every enemy on the line between the
      mob and its target with no equipped-spear gate.
    * `KN_BRANDISHSPEAR` (Brandish Spear) splash-damages the target and a
      nearby bystander with no mount/riding gate - a mob caster has no
      `option` bitmask to check in the first place.

  All three satisfy their declared mob requirements, so the sweep already
  exercises them for a clean result; these add the observable behavioural
  assertions.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @map "prontera"

  setup do
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
    :ok
  end

  test "a mob casting Two-Hand Quicken buffs itself through the anomalous target:target/level:30 row" do
    target =
      start_player_session(character: player_character(9_001, {158, 150}), position: {158, 150})

    mob = start_mob_session(unit_id: 9_101, map_name: @map, position: {150, 150})

    caster = %{mob_state(mob) | target_ref: {:player, target.character.id}}

    assert :ok = Executor.execute(caster, twohandquicken_row())

    refute StatusStorage.has_status?(:player, target.character.id, :sc_twohandquicken)

    status = StatusStorage.get_status(:mob, 9_101, :sc_twohandquicken)
    assert status != nil
    assert_in_delta status.expires_at - status.started_at, 10_000, 500
  end

  test "a mob casting Spear Stab damages every enemy on the line to its target" do
    primary =
      start_player_session(character: player_character(9_002, {152, 150}), position: {152, 150})

    bystander =
      start_player_session(character: player_character(9_003, {151, 150}), position: {151, 150})

    mob = start_mob_session(unit_id: 9_102, map_name: @map, position: {150, 150})

    primary_hp = current_hp(primary.pid)
    bystander_hp = current_hp(bystander.pid)

    caster = %{mob_state(mob) | target_ref: {:player, primary.character.id}}

    assert :ok = Executor.execute(caster, spearstab_row())

    assert eventually(fn -> current_hp(primary.pid) < primary_hp end)
    assert eventually(fn -> current_hp(bystander.pid) < bystander_hp end)
  end

  test "a mob casting Brandish Spear splash-damages nearby enemies with no riding gate" do
    primary =
      start_player_session(character: player_character(9_004, {151, 150}), position: {151, 150})

    bystander =
      start_player_session(character: player_character(9_005, {152, 150}), position: {152, 150})

    mob = start_mob_session(unit_id: 9_103, map_name: @map, position: {150, 150})

    primary_hp = current_hp(primary.pid)
    bystander_hp = current_hp(bystander.pid)

    caster = %{mob_state(mob) | target_ref: {:player, primary.character.id}}

    assert :ok = Executor.execute(caster, brandishspear_row())

    assert eventually(fn -> current_hp(primary.pid) < primary_hp end)
    assert eventually(fn -> current_hp(bystander.pid) < bystander_hp end)
  end

  defp mob_state(mob), do: get_mob_state(mob.pid)

  defp current_hp(pid), do: get_player_state(pid).stats.current_state.hp

  defp twohandquicken_row,
    do: %{skill: "KN_TWOHANDQUICKEN", skill_id: 60, target: :target, level: 30}

  defp spearstab_row, do: %{skill: "KN_SPEARSTAB", skill_id: 58, target: :target, level: 5}

  defp brandishspear_row,
    do: %{skill: "KN_BRANDISHSPEAR", skill_id: 57, target: :target, level: 5}

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
