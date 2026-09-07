defmodule Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator do
  @moduledoc """
  Coordinates single-hit magic damage for the booted game mode.

  Captures one MATK roll and the attacker's and defender's status/equipment
  inputs, then delegates ordinary arithmetic to `Mechanics.magic_damage/0`.
  Renewal applies cardfix before the skill ratio and MDEF; classic applies
  cardfix after MDEF and element. Both apply the ordinary element adjustment
  after MDEF, and only Renewal uses S.MAtk and MRes.

  Fixed amounts bypass calculation. Grand Cross retains a separate hybrid
  recipe. Reflection, absorption, hit division, packets and HP mutation belong
  to the delivery layer. Magic always hits and never rolls a critical here.
  """

  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @grand_cross_skill_id 254
  @magic_attack_flag BattleFlags.build(:magic, :long, true)
  @zero_equip_rates %{
    attack: %{race: 0, race2: 0, class: 0, element_target: 0, size: 0, atk_ele: 0, skill: 0},
    taken: %{race: 0, race2: 0, class: 0, element: 0, size: 0, skill: 0},
    ignore_mdef: 0
  }

  @typedoc "Result of a magic damage calculation. Magic never crits."
  @type magic_damage_result :: %{damage: non_neg_integer(), is_critical: false}

  @doc """
  Calculates one magic hit from the supplied combatant snapshots.

  Options:

    * `:skill_ratio`: percent of rolled MATK, default `100`.
    * `:bonus_matk`: flat addition after the skill ratio, default `0`.
    * `:element`: spell element, default `:neutral`.
    * `:skill_id`: selects equipment skill rates and the Grand Cross recipe.
    * `:fixed_damage`: returns this amount without rolls or modifier lookups.
    * `:ignore_mdef`: bypasses both MDEF components, not cardfix, element,
      skill/status channels or Renewal MRes. Default `false`.

  Percentage equipment MDEF-ignore affects hard MDEF only and uses the active
  mode's rounding. Missing trait slots are zero; classic ignores them entirely.
  """
  @spec calculate_magic_damage(Combatant.t() | map(), Combatant.t() | map(), keyword()) ::
          {:ok, magic_damage_result()} | {:error, atom()}
  def calculate_magic_damage(attacker, defender, opts \\ []) do
    cond do
      Keyword.get(opts, :fixed_damage) != nil ->
        {:ok, %{damage: Keyword.fetch!(opts, :fixed_damage), is_critical: false}}

      Keyword.get(opts, :skill_id) == @grand_cross_skill_id ->
        calculate_grand_cross_damage(attacker, defender, opts)

      true ->
        calculate_pipeline_damage(attacker, defender, opts)
    end
  end

  @doc """
  Rolls MATK from the half-open `matk_min`/`matk_max` band.

  A missing band uses deterministic `matk`; equal endpoints return that value.
  """
  @spec roll_matk(map()) :: non_neg_integer()
  def roll_matk(combat_stats) do
    DamageShared.roll(
      Map.get(combat_stats, :matk_min, combat_stats.matk),
      Map.get(combat_stats, :matk_max, combat_stats.matk)
    )
  end

  defp calculate_pipeline_damage(attacker, defender, opts) do
    matk = roll_matk(attacker.combat_stats)
    modifiers = combatant_modifiers(attacker)
    defender_modifiers = combatant_modifiers(defender)
    element = Keyword.get(opts, :element, :neutral)
    skill_id = Keyword.get(opts, :skill_id)
    equip = equipment_rates(attacker, defender, defender_modifiers, skill_id, element)
    {hard, soft} = mdef_values(defender, defender_modifiers)

    attack = %{
      size: equip.attack.size + status_rate(modifiers, :magic_addsize, Map.get(defender, :size)),
      race2: equip.attack.race2,
      element_target:
        equip.attack.element_target +
          status_rate(modifiers, :magic_addele, defender_element(defender)),
      atk_ele: equip.attack.atk_ele,
      race:
        equip.attack.race + status_rate(modifiers, :magic_addrace, Map.get(defender, :race)) +
          RaceModifiers.dragonology_matk_rate(attacker, Map.get(defender, :race)),
      class: equip.attack.class
    }

    taken = %{
      element: equip.taken.element,
      size: equip.taken.size,
      race2: equip.taken.race2,
      race:
        equip.taken.race +
          RaceModifiers.dragonology_resist_rate(defender, Map.get(attacker, :race)),
      class: equip.taken.class,
      magic: Map.get(defender_modifiers, :magic_damage_reduction, 0)
    }

    context = %{
      attack: attack,
      taken: taken,
      skill_ratio: Keyword.get(opts, :skill_ratio, 100),
      bonus_matk: Keyword.get(opts, :bonus_matk, 0),
      skill_atk_rate: equip.attack.skill,
      skill_taken_rate: equip.taken.skill,
      matk_rate: Map.get(modifiers, :matk_rate, 0),
      damage_multiplier: Map.get(modifiers, :damage_multiplier, 0),
      smatk: Map.get(attacker.combat_stats, :smatk, 0),
      mres: Map.get(defender.combat_stats, :mres, 0),
      hard_mdef: hard,
      soft_mdef: soft,
      ignore_mdef_rate: equip.ignore_mdef,
      ignore_mdef?: Keyword.get(opts, :ignore_mdef, false),
      element_modifier: DamageShared.apply_element(1, element, defender, modifiers)
    }

    damage = Mechanics.magic_damage().calculate(matk, context)
    {:ok, %{damage: damage, is_critical: false}}
  end

  defp status_rate(modifiers, family, value) do
    Map.get(modifiers, {family, value}, 0) + Map.get(modifiers, {family, :all}, 0)
  end

  defp defender_element(defender) do
    case Map.get(defender, :element, :neutral) do
      {element, _level} -> element
      element -> element
    end
  end

  defp calculate_grand_cross_damage(attacker, defender, opts) do
    skill_ratio = Keyword.get(opts, :skill_ratio, 100)
    hybrid_base = div(attacker.combat_stats.atk + roll_matk(attacker.combat_stats), 2)
    {hard_mdef, soft_mdef} = mdef_values(defender, combatant_modifiers(defender))

    damage =
      (div(hybrid_base * skill_ratio, 100) - hard_mdef - soft_mdef)
      |> DamageShared.apply_element(:holy, defender)
      |> DamageShared.apply_element(:holy, defender)
      |> DamageShared.clamp_min_one()

    {:ok, %{damage: damage, is_critical: false}}
  end

  defp mdef_values(defender, modifiers) do
    {unit_type, unit_id} = get_unit_type_and_id(defender)

    case StatusStorage.get_status(unit_type, unit_id, :sc_mdefset) do
      %{val1: value} when is_integer(value) ->
        {value, value}

      _missing ->
        mdef_rate = Map.get(modifiers, :mdef_rate, 0)
        hard = trunc(defender.combat_stats.mdef * (100 + mdef_rate) / 100)
        {hard, defender.combat_stats.soft_mdef}
    end
  end

  defp equipment_rates(
         %Combatant{} = attacker,
         %Combatant{} = defender,
         modifiers,
         skill_id,
         element
       ) do
    %{
      attack: EquipmentBonuses.magic_attack_rates(attacker, defender, skill_id, element),
      taken:
        EquipmentBonuses.magic_defense_rates(
          defender,
          attacker,
          element,
          modifiers,
          skill_id,
          @magic_attack_flag
        ),
      ignore_mdef: EquipmentBonuses.ignore_mdef_rate(attacker, defender)
    }
  end

  defp equipment_rates(_attacker, _defender, _modifiers, _skill_id, _element),
    do: @zero_equip_rates

  defp combatant_modifiers(combatant) do
    {unit_type, unit_id} = get_unit_type_and_id(combatant)
    ModifierCalculator.get_all_modifiers(unit_type, unit_id)
  end

  defp get_unit_type_and_id(combatant) do
    case combatant.unit_type do
      :player -> {:player, combatant.unit_id}
      :mob -> {:mob, combatant.unit_id}
      _ -> {:unknown, combatant.unit_id}
    end
  end
end
