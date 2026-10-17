defmodule Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator do
  @moduledoc """
  Single-hit BF_MISC damage calculation (traps, falcon, thrown stones, falling
  damage), shared by every misc hit in both modes.

  Mirrors the magic/physical calculator contract and result shape so downstream
  packet/HP-apply code is shared: it returns `%{damage: non_neg_integer(),
  is_critical: false}`. Misc attacks never crit.

  The skill supplies its level/fixed **base damage** via `:base_damage` (the
  per-level formula lives in the skill module, not here); this calculator
  applies the misc tail that follows it.

  ## Pipeline

  1. Base damage from `:base_damage` (a split splash divides it before).
  2. A player target's card reductions as one per-mille factor (see
     `EquipmentBonuses.misc_defense_cardfix/3`), unless the skill ignores
     defensive cards. A monster attacker's hit also matches the target's
     weapon-conditioned entries and never its magic-conditioned ones.
  3. A player attacker's skill damage rate for the skill, then a player
     target's skill resist rate.
  4. One attribute step (skill element vs defender element/level), unless the
     skill ignores elements.
  5. A negative result deals 0. There is no minimum of 1: an immune element
     deals 0.

  Misc hits never roll flee: every misc damage skill ignores it. The skill's
  ignore-defensive-cards and ignore-element flags come from its definition.
  BF_MISC applies no defense reduction: hard-DEF, soft-DEF, MDEF and the
  generic status `damage_multiplier` are all ignored.
  """

  import Bitwise

  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  @typedoc "Result of a misc damage calculation. Misc never crits."
  @type misc_damage_result :: %{
          damage: non_neg_integer(),
          is_critical: false
        }

  @doc """
  Calculates single-hit renewal misc (BF_MISC) damage against `defender`.

  ## Options

    - `:skill_id` - the misc skill (required); its definition decides whether
      the target's cards and the element table apply.
    - `:attack_flag` - the hit's battle flag (required), matched against the
      target's trigger-conditioned card entries; its range bit picks the near
      or long defense rate.
    - `:base_damage` - the skill's level/fixed base damage (default `0`).
    - `:element` - the skill's attack element (default `:neutral`).
    - `:fixed_damage` - when set, short-circuits the pipeline and returns that
      flat value (default `nil`).

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
  defp calculate_pipeline_damage(attacker, defender, opts) do
    skill_id = Keyword.fetch!(opts, :skill_id)
    {:ok, definition} = Catalog.by_id(skill_id)
    attack_flag = Keyword.fetch!(opts, :attack_flag)
    element = Keyword.get(opts, :element, :neutral)

    damage =
      opts
      |> Keyword.get(:base_damage, 0)
      |> trunc()
      |> defender_cardfix(attacker, defender, element, attack_flag, definition)
      |> skill_rates(attacker, defender, skill_id)
      |> element_step(element, attacker, defender, definition)

    {:ok, %{damage: max(damage, 0), is_critical: false}}
  end

  defp defender_cardfix(damage, attacker, %{unit_type: :player} = defender, element, flag, defn)
       when not defn.ignore_def_card do
    cards =
      EquipmentBonuses.misc_defense_cardfix(defender, attacker, %{
        element: element,
        ignore_element?: defn.ignore_element,
        status_modifiers: ModifierCalculator.get_all_modifiers(:player, defender.unit_id),
        attack_flag: card_flag(attacker, flag)
      })

    PhysicalAttack.defender_cardfix(damage, cards)
  end

  defp defender_cardfix(damage, _attacker, _defender, _element, _flag, _definition), do: damage

  # A monster's hit reads the target's weapon-conditioned cards, never its
  # magic-conditioned ones; the hit itself stays misc.
  defp card_flag(%{unit_type: :mob}, flag),
    do: (flag ||| BattleFlags.type_bit(:weapon)) &&& bnot(BattleFlags.type_bit(:magic))

  defp card_flag(_attacker, flag), do: flag

  defp skill_rates(damage, attacker, defender, skill_id) do
    damage
    |> add_rate(attacker, &EquipmentBonuses.skill_atk_rate(&1, skill_id), 1)
    |> add_rate(defender, &EquipmentBonuses.sub_skill_rate(&1, skill_id), -1)
  end

  defp add_rate(damage, %{unit_type: :player} = unit, rate, sign),
    do: damage + sign * div(damage * rate.(unit), 100)

  defp add_rate(damage, _unit, _rate, _sign), do: damage

  defp element_step(damage, _element, _attacker, _defender, %{ignore_element: true}), do: damage

  defp element_step(damage, element, attacker, defender, _definition),
    do: DamageShared.apply_element_step(damage, element, attacker, defender)
end
