defmodule Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator do
  @moduledoc """
  Single-hit renewal magic damage calculation.

  Mirrors the physical `DamageCalculator` interface and result shape so
  downstream packet/HP-apply code is shared: it returns the same
  `%{damage: non_neg_integer(), is_critical: false}`. Magic always hits and
  never crits, so there is no hit/flee or critical step.

  ## Pipeline

  1. Base MATK from `attacker.combat_stats.matk`.
  2. Skill ratio + flat MATK bonus.
  3. Element resistance (skill element vs defender element/level).
  4. Generic status `damage_multiplier`.
  5. Renewal MDEF reduction (`battle.cpp:6105`):
     `dmg = matk * (1000 + hardMDEF) / (1000 + 10*hardMDEF) - softMDEF`.
  6. Min-1 clamp.

  Hard MDEF already folds the defender's status/equipment MDEF (players) or
  the mob's flat MDEF, so status defense modifiers are not re-applied here.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  @typedoc """
  Result of a magic damage calculation. Magic never crits.
  """
  @type magic_damage_result :: %{
          damage: non_neg_integer(),
          is_critical: false
        }

  @doc """
  Calculates single-hit renewal magic damage from `attacker` to `defender`.

  ## Options

    - `:skill_ratio` - percent of base MATK the skill deals (default `100`).
    - `:bonus_matk` - flat MATK added after the skill-ratio step (default `0`).
    - `:element` - the skill's attack element used for the defender's element
      resistance step (default `:neutral`).
    - `:fixed_damage` - when set, short-circuits the entire pipeline and returns
      that flat value (default `nil`).

  ## Returns

    - `{:ok, %{damage: non_neg_integer(), is_critical: false}}` on success.
    - `{:error, reason}` on failure.
  """
  @spec calculate_magic_damage(Combatant.t() | map(), Combatant.t() | map(), keyword()) ::
          {:ok, magic_damage_result()} | {:error, atom()}
  def calculate_magic_damage(attacker, defender, opts \\ []) do
    case Keyword.get(opts, :fixed_damage) do
      nil -> calculate_pipeline_damage(attacker, defender, opts)
      fixed_damage -> {:ok, %{damage: fixed_damage, is_critical: false}}
    end
  end

  @spec calculate_pipeline_damage(map(), map(), keyword()) :: {:ok, magic_damage_result()}
  defp calculate_pipeline_damage(attacker, defender, opts) do
    skill_ratio = Keyword.get(opts, :skill_ratio, 100)
    bonus_matk = Keyword.get(opts, :bonus_matk, 0)
    element = Keyword.get(opts, :element, :neutral)

    base_matk = attacker.combat_stats.matk
    skilled = div(base_matk * skill_ratio, 100) + bonus_matk
    modifiers = attacker_modifiers(attacker)

    damage =
      skilled
      |> DamageShared.apply_element(element, defender)
      |> DamageShared.apply_damage_multiplier(modifiers)
      |> apply_mdef_formula(defender)
      |> DamageShared.clamp_min_one()

    {:ok, %{damage: damage, is_critical: false}}
  end

  @spec apply_mdef_formula(number(), map()) :: number()
  defp apply_mdef_formula(damage, defender) do
    hard = defender.combat_stats.mdef
    soft = defender.combat_stats.soft_mdef
    effective_hard = if hard == -100, do: -99, else: hard

    damage * (1000 + effective_hard) / (1000 + 10 * effective_hard) - soft
  end

  @spec attacker_modifiers(map()) :: map()
  defp attacker_modifiers(attacker) do
    {unit_type, unit_id} = get_unit_type_and_id(attacker)
    ModifierCalculator.get_all_modifiers(unit_type, unit_id)
  end

  @spec get_unit_type_and_id(map()) :: {atom(), integer()}
  defp get_unit_type_and_id(combatant) do
    case combatant.unit_type do
      :player -> {:player, combatant.unit_id}
      :mob -> {:mob, combatant.unit_id}
      _ -> {:unknown, combatant.unit_id}
    end
  end
end
