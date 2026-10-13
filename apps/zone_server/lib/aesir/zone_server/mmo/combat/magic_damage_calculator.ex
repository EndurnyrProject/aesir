defmodule Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator do
  @moduledoc """
  Coordinates ordinary single-hit magic damage for the booted game mode.

  Captures one MATK roll and the attacker's and defender's status/equipment
  inputs, then delegates arithmetic to `Mechanics.magic_damage/0`.
  Renewal applies cardfix before the skill ratio and MDEF; classic applies
  cardfix after MDEF and element. Both run one attribute step after MDEF and the
  reference minimum of 1, owned here because it can burn a web; an immune element
  deals 0. Only Renewal uses S.MAtk and MRes. `:ignore_element` skips the step.

  Fixed amounts bypass calculation. Skill-owned formulas use shared input
  primitives directly. Reflection, absorption, hit division, packets and HP
  mutation belong to delivery. Magic never rolls a critical here.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  @typedoc "Result of a magic damage calculation. Magic never crits."
  @type magic_damage_result :: %{damage: integer(), is_critical: false}

  @doc """
  Calculates one ordinary magic hit from the supplied snapshots.

  Options:

    * `:skill_ratio`: percent of rolled MATK, default `100`.
    * `:bonus_matk`: flat addition after the skill ratio, default `0`.
    * `:element`: spell element, default `:neutral`.
    * `:skill_id`: selects equipment skill rates, never an alternate formula.
    * `:matk_divisor`: split a rolled MATK among splash recipients before the
      skill ratio, defense and element steps. Default `1`.
    * `:fixed_damage`: returns this amount without rolls or modifier lookups.
    * `:ignore_mdef`: bypasses both MDEF components, not cardfix, element,
      skill/status channels or Renewal MRes. Default `false`.
    * `:attack_flag`: the hit's battle flag, whose range class selects the
      target's range-flagged resists. Default a long-range magic skill hit.

  Percentage equipment MDEF-ignore affects hard MDEF only and uses the active
  mode's rounding. Missing trait slots are zero; classic ignores them entirely.
  """
  @spec calculate_magic_damage(Combatant.t() | map(), Combatant.t() | map(), keyword()) ::
          {:ok, magic_damage_result()} | {:error, atom()}
  def calculate_magic_damage(attacker, defender, opts \\ []) do
    case Keyword.get(opts, :fixed_damage) do
      nil -> calculate_pipeline_damage(attacker, defender, opts)
      damage -> {:ok, %{damage: damage, is_critical: false}}
    end
  end

  @doc "Rolls the half-open MATK band or its deterministic scalar when the band is absent."
  @spec roll_matk(map()) :: non_neg_integer()
  defdelegate roll_matk(combat_stats), to: DamageInputs

  defp calculate_pipeline_damage(attacker, defender, opts) do
    matk = div(roll_matk(attacker.combat_stats), Keyword.get(opts, :matk_divisor, 1))
    modifiers = combatant_modifiers(attacker)
    defender_modifiers = combatant_modifiers(defender)
    context = DamageInputs.magic_context(attacker, defender, opts, modifiers, defender_modifiers)
    formulas = Mechanics.magic_damage()

    damage =
      matk
      |> formulas.pre_element(context)
      |> element_step(attacker, defender, opts, modifiers)
      |> formulas.post_element(context)

    {:ok, %{damage: damage, is_critical: false}}
  end

  defp element_step(damage, attacker, defender, opts, modifiers) do
    if Keyword.get(opts, :ignore_element, false) do
      damage
    else
      element = Keyword.get(opts, :element, :neutral)

      DamageShared.apply_element_step(damage, element, attacker, defender,
        attacker_modifiers: modifiers
      )
    end
  end

  defp combatant_modifiers(%{unit_type: type, unit_id: id})
       when type in [:homunculus, :mercenary, :mob, :npc, :pet, :player, :skill_unit],
       do: ModifierCalculator.get_all_modifiers(type, id)

  defp combatant_modifiers(_combatant), do: %{}
end
