defmodule Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator do
  @moduledoc """
  Single-hit renewal BF_MISC damage calculation (traps, falling damage).

  Mirrors the magic/physical calculator contract and result shape so downstream
  packet/HP-apply code is shared: it returns `%{damage: non_neg_integer(),
  is_critical: false}`. Misc attacks never crit.

  The skill supplies its level/fixed **base damage** via `:base_damage` (the
  trap's per-level formula lives in the skill module, not here); this calculator
  only applies the misc tail.

  ## Pipeline

  1. Base damage from `:base_damage`.
  2. Element resistance (skill element vs defender element/level).
  3. Min-1 clamp.

  Verified vs rAthena `battle_calc_misc_attack` (battle.cpp:6290): BF_MISC applies
  **NO defense reduction** - it never calls `battle_calc_defense_reduction` (the
  eDEF/MDEF curve belongs to the weapon/magic paths). Element is applied; hard-DEF,
  soft-DEF, MDEF and the generic status `damage_multiplier` are all ignored.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared

  @typedoc "Result of a misc damage calculation. Misc never crits."
  @type misc_damage_result :: %{
          damage: non_neg_integer(),
          is_critical: false
        }

  @doc """
  Calculates single-hit renewal misc (BF_MISC) damage against `defender`.

  ## Options

    - `:base_damage` - the skill's level/fixed base damage (default `0`).
    - `:element` - the skill's attack element for the defender resistance step
      (default `:neutral`).
    - `:fixed_damage` - when set, short-circuits the pipeline and returns that
      flat value (default `nil`).
    - `:ignore_element` - bypasses the element table when true (default `false`).

  ## Returns

    - `{:ok, %{damage: non_neg_integer(), is_critical: false}}` on success.
    - `{:error, reason}` on failure.
  """
  @spec calculate_misc_damage(Combatant.t() | map(), Combatant.t() | map(), keyword()) ::
          {:ok, misc_damage_result()} | {:error, atom()}
  def calculate_misc_damage(attacker, defender, opts \\ []) do
    case Keyword.get(opts, :fixed_damage) do
      nil -> calculate_pipeline_damage(attacker, defender, opts)
      fixed_damage -> {:ok, %{damage: fixed_damage, is_critical: false}}
    end
  end

  @spec calculate_pipeline_damage(map(), map(), keyword()) :: {:ok, misc_damage_result()}
  defp calculate_pipeline_damage(_attacker, defender, opts) do
    base_damage = Keyword.get(opts, :base_damage, 0)
    element = Keyword.get(opts, :element, :neutral)

    damage =
      if Keyword.get(opts, :ignore_element, false) do
        base_damage
      else
        DamageShared.apply_element(base_damage, element, defender)
      end
      |> DamageShared.clamp_min_one()

    {:ok, %{damage: damage, is_critical: false}}
  end
end
