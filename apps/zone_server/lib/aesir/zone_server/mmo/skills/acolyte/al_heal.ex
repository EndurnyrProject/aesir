defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal do
  @moduledoc """
  Heal (AL_HEAL). Computes a renewal heal value and either restores HP on an ally
  or deals it as holy magic damage when the target is undead or demon.

  rAthena RENEWAL formula (`src/map/skill.cpp`, `skill_calc_heal`, default branch):

    Line 585:
      hp = (status_get_lv(src) + status_get_int(src)) / 5 * 30 * skill_lv / 10;

    Lines 696-730 (MATK part of the RE heal formula):
      min = status_base_matk_min(...);
      max = status_base_matk_max(...);
      if (max > min) hp += min + rnd() % (max - min); else hp += min;

  Elixir equivalent:
    base = div(div(base_level + int, 5) * 30 * level, 10)
    heal = base + DamageShared.roll(heal_matk_min, heal_matk_max)

  Line 771-772 (HPlus heal boost, applied as the final step):
    if (status_get_hplus(src) > 0) hp += hp * status_get_hplus(src) / 100;

  Elixir equivalent:
    heal + div(heal * hplus, 100)

  Verified vs rAthena skill.cpp:705-729: the heal MATK band is
  `status_base_matk_min/max + weapon MATK variance` ONLY - it does NOT include
  flat item/status MATK (ematk, matk_rate). So heal rolls over the dedicated
  `heal_matk_min`/`heal_matk_max` band (base_matk + weapon variance, no flat),
  not the combat `matk_min`/`matk_max`. With no MATK weapon the band collapses
  and the heal is deterministic, equal to `base + base_matk`.

  The caster's equipment heal-power bonus (`bonus bHealPower`) is a further
  percent step applied after the HPlus one, and is deliberately kept separate
  from the trait-derived HPlus rather than summed into it.

  The cast computes the base heal amount only. The recipient's `received_heal_rate`
  bonus (SC_INCHEALRATE) is applied downstream on the generic `HealthHandler.apply_heal`
  path that every `Combat.apply_heal` flows through. Still deferred here: Meditatio's
  caster-side heal-power bonus.

  The caster's stats are read generically through `caster.__struct__.to_combatant/1`,
  so a `%MobState{}` caster heals off its own INT/base level the same way a player
  does; mobs simply have no equipment (`heal_power` reads as 0) and no HPlus trait.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 28,
    name: :al_heal,
    display_name: "Heal",
    max_level: 10,
    target_type: :target_any,
    damage_type: :no_damage,
    range: 9,
    element: :holy,
    sp_cost: [13, 16, 19, 22, 25, 28, 31, 34, 37, 40],
    after_cast_delay: List.duplicate(500, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @doc """
  Casts Heal on the given target.

  Computes the renewal heal value from the caster's stats and skill level,
  then branches on the target's race:
  - `:undead` or `:demon` — the heal value is dealt as a holy magic hit via
    `Combat.execute_magic_damage/4`.
  - All others (including players and unresolvable targets) — HP is restored
    via `Combat.apply_heal/4`.
  """
  @spec cast(Active.caster(), :self | {:unit, integer()}, pos_integer(), struct()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, target, level, _definition) do
    combatant = caster.__struct__.to_combatant(caster)
    heal_value = compute_heal(combatant, level)
    target_id = Active.resolve_target_id(caster, target)

    case Combat.resolve_combatant(target_id) do
      {:ok, %{race: race}} when race in [:undead, :demon] ->
        case Combat.execute_magic_damage(caster, target_id, heal_value,
               skill_id: 28,
               skill_level: level,
               element: :holy,
               skip_range: true
             ) do
          :ok -> {:ok, caster}
          {:error, _} = error -> error
        end

      _ ->
        Combat.apply_heal(target_unit_type(target_id), target_id, heal_value, combatant.unit_id)
        {:ok, caster}
    end
  end

  defp compute_heal(combatant, level) do
    combat_stats = combatant.combat_stats

    base =
      div(div(combatant.progression.base_level + combatant.base_stats.int, 5) * 30 * level, 10)

    matk_min = Map.get(combat_stats, :heal_matk_min, combat_stats.matk)
    matk_max = Map.get(combat_stats, :heal_matk_max, combat_stats.matk)
    heal = base + DamageShared.roll(matk_min, matk_max)
    hplus = Map.get(combat_stats, :hplus, 0)
    heal_power = Map.get(combatant.equip_modifiers, :heal_power, 0)

    heal
    |> then(&(&1 + div(&1 * hplus, 100)))
    |> then(&(&1 + div(&1 * heal_power, 100)))
  end

  @spec target_unit_type(integer()) :: :mob | :player
  defp target_unit_type(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
  end
end
