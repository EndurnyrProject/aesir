defmodule Aesir.ZoneServer.Mmo.Skills.AlHeal do
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
    heal = base + matk

  Deferred: heal-rate bonuses (Meditatio, SC_INCHEALRATE, item scripts, MATK min/max
  variance). All stat modifiers other than the base formula are out of scope for this task.
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
    via `Combat.apply_heal/3`.
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
               element: :holy
             ) do
          :ok -> {:ok, caster}
          {:error, _} = error -> error
        end

      _ ->
        Combat.apply_heal(target_id, heal_value, caster_id)
        {:ok, caster}
    end
  end

  defp compute_heal(%{base_level: base_level, int: int_val, matk: matk}, level) do
    div(div(base_level + int_val, 5) * 30 * level, 10) + matk
  end
end
