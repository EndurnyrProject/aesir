defmodule Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator do
  @moduledoc """
  Coordinates ordinary single-hit magic damage for the booted game mode.

  Captures one MATK roll and the attacker's and defender's status/equipment
  inputs, then delegates arithmetic to `Mechanics.magic_damage/0`.
  Renewal applies cardfix before the skill ratio and MDEF; classic applies
  cardfix after MDEF and element. Both run one attribute step after MDEF and the
  reference minimum of 1, owned here because it can burn a web; an immune element
  deals 0. Only Renewal uses S.MAtk and MRes. The `:skill_id`'s damage flags
  (`ignore_atk_card`, `ignore_def_card`, `ignore_element`) skip the matching card
  channels, and `ignore_element` (or the `:ignore_element` option) the element step.

  An infinite-defense target (`Combatant.infinite_defense?/2`) takes exactly 1
  before any other step, fixed amounts included; delivery still divides, reduces
  and absorbs it. Fixed amounts bypass calculation. Skill-owned formulas use shared input
  primitives directly. Reflection, absorption, hit division, packets and HP
  mutation belong to delivery. Magic never rolls a critical here.
  """

  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  @typedoc "Result of a magic damage calculation. Magic never crits."
  @type magic_damage_result :: %{damage: integer(), is_critical: false}

  @doc """
  Calculates one ordinary magic hit from the supplied snapshots.

  Options:

    * `:skill_ratio`: percent of rolled MATK, default `100`.
    * `:bonus_matk`: flat addition after the skill ratio, default `0`.
    * `:element`: spell element, default `:neutral`.
    * `:skill_id`: selects equipment skill rates and the skill's damage flags,
      never an alternate formula.
    * `:matk_divisor`: split a rolled MATK among splash recipients before the
      skill ratio, defense and element steps. Default `1`.
    * `:fixed_damage`: returns this amount without rolls or modifier lookups.
    * `:base_matk`: a skill's own base that replaces the MATK roll and the
      stages only a rolled MATK takes (S.MAtk, `:skill_ratio`, `:bonus_matk`);
      cardfix, skill rates, MRes, MDEF and element still run.
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
    cond do
      Combatant.infinite_defense?(defender, BattleFlags.type_bit(:magic)) ->
        {:ok, %{damage: 1, is_critical: false}}

      damage = Keyword.get(opts, :fixed_damage) ->
        {:ok, %{damage: damage, is_critical: false}}

      true ->
        calculate_pipeline_damage(attacker, defender, opts)
    end
  end

  @doc "Rolls the half-open MATK band or its deterministic scalar when the band is absent."
  @spec roll_matk(map()) :: non_neg_integer()
  defdelegate roll_matk(combat_stats), to: DamageInputs

  defp calculate_pipeline_damage(attacker, defender, opts) do
    opts = Keyword.merge(opts, skill_flags(opts))
    modifiers = combatant_modifiers(attacker)
    defender_modifiers = combatant_modifiers(defender)
    context = DamageInputs.magic_context(attacker, defender, opts, modifiers, defender_modifiers)

    {matk, context} =
      case Keyword.get(opts, :base_matk) do
        nil ->
          {div(roll_matk(attacker.combat_stats), Keyword.get(opts, :matk_divisor, 1)), context}

        base ->
          {base, %{context | smatk: 0, skill_ratio: 100, bonus_matk: 0}}
      end

    formulas = Mechanics.magic_damage()

    damage =
      matk
      |> formulas.pre_element(context)
      |> element_step(attacker, defender, opts, modifiers)
      |> formulas.post_element(context)

    {:ok, %{damage: damage, is_critical: false}}
  end

  defp skill_flags(opts) do
    with id when is_integer(id) <- Keyword.get(opts, :skill_id),
         {:ok, definition} <- Catalog.by_id(id) do
      [
        ignore_atk_card: definition.ignore_atk_card,
        ignore_def_card: definition.ignore_def_card,
        ignore_element: definition.ignore_element or Keyword.get(opts, :ignore_element, false)
      ]
    else
      _no_skill -> []
    end
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
       do: ModifierCalculator.get_battle_modifiers(type, id)

  defp combatant_modifiers(_combatant), do: %{}
end
