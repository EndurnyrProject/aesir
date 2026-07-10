defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.ElementalNuke do
  @moduledoc """
  Single-target magic damage of a fixed element (`NPC_FIREATTACK`, `MG_*` bolts,
  ...).

  Damage is delivered through `Combat.execute_magic_damage/4`, whose `amount` is
  an explicit pre-element value: Combat applies the target's element resistance
  (and clamps to a minimum of 1) but intentionally bypasses MDEF. The amount is
  the mob's MATK times the skill level — the bolt-family model of `level` hits
  at 100% MATK each, the design's accepted archetype approximation.
  """

  @behaviour Aesir.ZoneServer.Mmo.MobSkill.Archetype

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Unit.Mob.CombatCalculations, as: MobCombatCalc
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @impl true
  def apply(%MobState{} = caster, {:unit, :player, target_id}, params, level) do
    amount = MobCombatCalc.calculate_magic_attack(caster.mob_data) * level

    # attack_range only feeds execute_magic_damage's range gate (the explicit
    # amount bypasses the ATK pipeline entirely), so a local override lets the
    # nuke reach the mob's skill range instead of its melee reach.
    # ponytail: execute_magic_damage applies element but bypasses MDEF (the
    # documented approximation); swap to execute_magic_attack when full
    # MATK/MDEF pipeline fidelity is wanted.
    mob_data = caster.mob_data
    cast_range = max(mob_data.attack_range, mob_data.skill_range)
    caster = %{caster | mob_data: %{mob_data | attack_range: cast_range}}

    Combat.execute_magic_damage(caster, target_id, amount,
      skill_id: params.skill_id,
      skill_level: level,
      element: params.element
    )
  end

  def apply(%MobState{}, _target, _params, _level), do: {:error, :invalid_target}
end
