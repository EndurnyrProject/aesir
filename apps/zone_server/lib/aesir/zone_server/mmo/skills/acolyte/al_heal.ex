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
  alias Aesir.ZoneServer.Unit.Player.PlayerState

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
  @spec cast(struct(), :self | {:unit, integer()}, pos_integer(), struct()) ::
          {:ok, struct()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, target, level, _definition) do
    stats = PlayerState.get_stats(caster)
    heal_value = compute_heal(stats, level)
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
        Combat.apply_heal(:player, target_id, heal_value, caster_id)
        {:ok, caster}
    end
  end

  defp compute_heal(%{base_level: base_level, int: int_val} = stats, level) do
    base = div(div(base_level + int_val, 5) * 30 * level, 10)
    matk_min = Map.get(stats, :heal_matk_min, stats.matk)
    matk_max = Map.get(stats, :heal_matk_max, stats.matk)
    heal = base + DamageShared.roll(matk_min, matk_max)
    hplus = Map.get(stats, :hplus, 0)
    heal_power = Map.get(stats, :heal_power, 0)

    heal
    |> then(&(&1 + div(&1 * hplus, 100)))
    |> then(&(&1 + div(&1 * heal_power, 100)))
  end
end
