defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsMagicalbullet do
  @moduledoc """
  Magical Bullet (GS_MAGICALBULLET) costs 7 SP and one coin in both modes.

  Pre-renewal it is a Ghost weapon attack at 9 cells with a 100% ratio that
  adds the caster's rolled MATK (`matk_min + rnd() % (matk_max - matk_min)`,
  or `matk_min` for a degenerate band) after the skill ratio and before
  defence (`battle.cpp` `battle_calc_skill_constant_addition`).

  Renewal it starts SC_MAGICALBULLET on the caster for 30 s; the status adds
  MATK to the weapon ATK of every physical hit (see `MagicalBullet`).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 507,
    name: :gs_magicalbullet,
    display_name: "Magical Bullet",
    max_level: 1,
    requires: [],
    target_type: [renewal: :self, pre_renewal: :target_enemy],
    damage_type: [renewal: :no_damage, pre_renewal: :damage],
    damage_kind: [renewal: :magic, pre_renewal: :weapon],
    element: [renewal: :neutral, pre_renewal: :ghost],
    range: [renewal: 0, pre_renewal: -9],
    sp_cost: [7],
    sphere_cost: [1],
    duration: [renewal: [30_000], pre_renewal: []]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @behaviour Active

  @impl Active
  def cast(caster, target, level, definition) do
    case GameMode.mode() do
      :renewal ->
        buff(:player, caster.character_id, level, definition)
        {:ok, caster}

      :pre_renewal ->
        with :ok <- shoot(caster, target_unit(target), level, definition), do: {:ok, caster}
    end
  end

  @impl Active
  def mob_cast(%MobState{instance_id: id} = caster, target, level, definition, _row) do
    case GameMode.mode() do
      :renewal ->
        buff(:mob, id, level, definition)
        {:ok, caster}

      :pre_renewal ->
        shoot(caster, target_unit(target), level, definition)
    end
  end

  defp buff(unit_type, unit_id, level, definition) do
    StatusInterpreter.apply_status(unit_type, unit_id, :sc_magicalbullet,
      val1: level,
      caster_id: unit_id,
      duration: hd(definition.duration)
    )
  end

  defp target_unit({:unit, type, id}) when is_atom(type), do: {type, id}
  defp target_unit({:unit, unit}), do: unit
  defp target_unit(unit), do: unit

  defp shoot(caster, target, level, definition) do
    attacker = caster.__struct__.to_combatant(caster)

    Combat.execute_skill_attack(caster, target,
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100,
      element: definition.element,
      bonus_atk: DamageInputs.roll_matk(attacker.combat_stats),
      skip_range: true,
      skip_crit: true
    )
  end
end
