defmodule Aesir.ZoneServer.Integration.MonkMobCastTest do
  @moduledoc """
  Proves the two Monk skills whose player modules could not run for a mob caster
  now execute correctly through the mob-skill `Executor` against live sessions:

    * `MO_BODYRELOCATION` (Snap) relocates the mob next to its target through the
      mob session's authoritative reposition path (spatial index updated);
    * `MO_BALKYOUNG` (Ki Explosion) damages, knocks back, and stuns its player
      targets using the caster's generic unit identity (no player-only state).

  Both satisfy their declared mob requirements, so the sweep exercises them
  too; these add the observable behavioural assertions.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @map "prontera"

  # Pin the landed hit, the 70% stun roll, and the status-landing resistance so
  # the splash-damage/stun assertions are deterministic; their probabilistic
  # paths are covered by unit tests.
  setup do
    Mimic.copy(HitCalculations)
    Mimic.copy(Resistance)
    Mimic.copy(Formulas)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
    stub(Resistance, :roll_success, fn _rate -> true end)
    stub(Formulas, :ki_explosion_stun_rate, fn -> 100 end)
    :ok
  end

  test "a mob casting Snap relocates next to its target through the mob session" do
    target =
      start_player_session(character: player_character(8_001, {158, 150}), position: {158, 150})

    mob = start_mob_session(unit_id: 8_101, map_name: @map, position: {150, 150})

    caster = %{mob_state(mob) | target_ref: {:player, target.character.id}}

    assert :ok = Executor.execute(caster, snap_row())

    assert eventually(fn ->
             case SpatialIndex.get_unit_position(:mob, 8_101) do
               {:ok, {x, y, @map}} ->
                 {x, y} != {150, 150} and Geometry.chebyshev_distance(x, y, 158, 150) == 1

               _ ->
                 false
             end
           end)

    state = get_mob_state(mob.pid)
    assert {state.x, state.y} != {150, 150}
    assert Geometry.chebyshev_distance(state.x, state.y, 158, 150) == 1
  end

  test "a boss mob casting Snap relocates through its authoritative self-movement path" do
    target =
      start_player_session(character: player_character(8_011, {158, 150}), position: {158, 150})

    boss =
      start_mob_session(
        unit_id: 8_111,
        map_name: @map,
        position: {150, 150},
        modes: [:boss]
      )

    caster = %{mob_state(boss) | target_ref: {:player, target.character.id}}

    assert :ok = Executor.execute(caster, snap_row())

    assert eventually(fn ->
             match?(
               {:ok, {x, y, @map}}
               when {x, y} != {150, 150} and
                      abs(x - 158) <= 1 and abs(y - 150) <= 1,
               SpatialIndex.get_unit_position(:mob, 8_111)
             )
           end)

    state = get_mob_state(boss.pid)
    assert MobState.is_boss?(state)
    assert {state.x, state.y} != {150, 150}
    assert Geometry.chebyshev_distance(state.x, state.y, 158, 150) == 1
  end

  test "a mob casting Ki Explosion damages, knocks back, and stuns its player targets" do
    primary =
      start_player_session(character: player_character(8_002, {151, 150}), position: {151, 150})

    bystander =
      start_player_session(character: player_character(8_003, {152, 150}), position: {152, 150})

    mob = start_mob_session(unit_id: 8_102, map_name: @map, position: {150, 150})

    primary_hp = get_player_state(primary.pid).stats.current_state.hp
    bystander_hp = get_player_state(bystander.pid).stats.current_state.hp

    caster = %{mob_state(mob) | target_ref: {:player, primary.character.id}}

    assert :ok = Executor.execute(caster, ki_explosion_row())

    # Splash damage reaches both players; the stun rides the caster's mob identity.
    assert eventually(fn -> current_hp(primary.pid) < primary_hp end)
    assert eventually(fn -> current_hp(bystander.pid) < bystander_hp end)

    assert StatusStorage.has_status?(:player, primary.character.id, :sc_stun)
    assert StatusStorage.has_status?(:player, bystander.character.id, :sc_stun)

    # The off-center bystander is knocked away from the blast at the primary's cell.
    assert eventually(fn ->
             match?(
               {:ok, {x, _y, @map}} when x > 152,
               SpatialIndex.get_unit_position(:player, 8_003)
             )
           end)
  end

  defp mob_state(mob), do: get_mob_state(mob.pid)

  defp current_hp(pid), do: get_player_state(pid).stats.current_state.hp

  defp snap_row, do: %{skill: "MO_BODYRELOCATION", skill_id: 264, target: :target, level: 1}

  defp ki_explosion_row, do: %{skill: "MO_BALKYOUNG", skill_id: 1_016, target: :target, level: 1}

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
