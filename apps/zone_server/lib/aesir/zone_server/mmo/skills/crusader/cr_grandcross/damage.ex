defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrGrandcross.Damage do
  @moduledoc """
  Grand Cross's pure hybrid recipe, including its self-damage rule.

  Renewal averages attack contributions and subtracts flat physical and magic
  defense. Classic adds separately defended physical and magic contributions;
  a player's physical base takes the positive equipment non-critical rate
  before its DEF.
  Enemy hits receive two holy attribute steps; player self-hits receive one holy
  step and one half-rate. Inputs are already captured and rolled, and every
  attribute step runs through the coordinator's `element_step`, so an immune
  target takes 0.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Mechanics.Defense.PreRenewal, as: ClassicDefense
  alias Aesir.ZoneServer.Mmo.Mechanics.MagicDamage
  alias Aesir.ZoneServer.Mmo.Mechanics.MagicDamage.PreRenewal, as: ClassicMagic
  alias Aesir.ZoneServer.Mmo.Mechanics.MagicDamage.Renewal, as: RenewalMagic
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.PreRenewal, as: ClassicAttack

  @typedoc """
  Skill-owned numeric inputs; non-player attack is not a synthetic player
  snapshot. `:non_crit_atk_rate` is the caster's equipment non-critical rate,
  read only by the classic player physical base (absent reads 0).
  """
  @type inputs :: %{
          optional(:non_crit_atk_rate) => integer(),
          caster_ref: {atom(), integer()},
          target_ref: {atom(), integer()},
          level: pos_integer(),
          physical: {:player, PhysicalAttack.parts()} | {:non_player, integer()},
          physical_defense: {integer(), integer()},
          physical_ignore_rate: integer(),
          size_rate: integer(),
          element_step: (integer(), atom() -> integer()),
          equipment_atk_rate: integer(),
          matk: integer(),
          magic: MagicDamage.context()
        }

  @doc "Returns a formula-complete amount before recipient absorption and delivery."
  @spec calculate(GameMode.t(), inputs()) :: integer()
  def calculate(:renewal, %{magic: magic} = inputs) do
    {hard, soft} = physical_defense(inputs)
    physical = renewal_physical(inputs)

    magical =
      inputs.matk
      |> RenewalMagic.attacker_cardfix(magic.attack)
      |> MagicDamage.defender_cardfix(magic.taken)
      |> MagicDamage.skill_rate(magic.smatk)
      |> MagicDamage.skill_damage(magic)
      |> MagicDamage.skill_rate(-magic.skill_taken_rate)
      |> DamageShared.res_reduction(magic.mres)
      |> MagicDamage.skill_rate(magic.skill_atk_rate)

    combined = div(physical + magical, 2)

    damage =
      div(combined * (100 + 40 * inputs.level), 100) - hard - soft - magic.hard_mdef -
        magic.soft_mdef

    damage |> first_holy(inputs) |> finish(inputs)
  end

  def calculate(:pre_renewal, %{magic: magic} = inputs) do
    physical = classic_physical(inputs)

    magical =
      inputs.matk
      |> MagicDamage.skill_damage(magic)
      |> MagicDamage.skill_rate(magic.skill_atk_rate)
      |> MagicDamage.skill_rate(-magic.skill_taken_rate)
      |> classic_magic_defense(magic)

    damage = div(max(physical + magical, 1) * (100 + 40 * inputs.level), 100)

    damage
    |> first_holy(inputs)
    |> ClassicMagic.attacker_cardfix(magic.attack)
    |> MagicDamage.defender_cardfix(magic.taken)
    |> finish(inputs)
  end

  defp renewal_physical(%{physical: {:non_player, amount}}), do: amount

  defp renewal_physical(%{physical: {:player, parts}} = inputs) do
    multiplier = if parts.hand == :right_hand, do: 2, else: 1
    status = inputs.element_step.(parts.status_atk, :neutral) * multiplier

    weapon =
      inputs.element_step.(
        div((parts.weapon_atk + parts.overrefine_atk) * inputs.size_rate, 100),
        :holy
      )

    equipment = inputs.element_step.(parts.flat_atk, :holy)
    status + weapon + equipment + div((weapon + equipment) * inputs.equipment_atk_rate, 100)
  end

  defp classic_physical(%{physical: {:player, parts}} = inputs) do
    base =
      (parts.status_atk + parts.flat_atk + div(parts.weapon_atk * inputs.size_rate, 100) +
         parts.overrefine_atk)
      |> ClassicAttack.non_crit_bonus(Map.get(inputs, :non_crit_atk_rate, 0))

    classic_defense(base, physical_defense(inputs)) + parts.refine_atk
  end

  defp classic_physical(%{physical: {:non_player, amount}} = inputs),
    do: classic_defense(amount, physical_defense(inputs))

  defp physical_defense(%{physical_defense: {hard, soft}, physical_ignore_rate: rate}) do
    rate = min(max(rate, 0), 100)
    {hard - div(hard * rate, 100), soft - div(soft * rate, 100)}
  end

  defp classic_defense(amount, {hard, soft}),
    do:
      ClassicDefense.apply_def(amount, %{
        hard_def: hard,
        soft_def: soft,
        attacker_level: nil,
        ignore_soft_def?: false
      })

  defp classic_magic_defense(damage, %{ignore_mdef?: true}), do: damage

  defp classic_magic_defense(damage, magic) do
    rate = min(max(magic.ignore_mdef_rate, 0), 100)
    hard = magic.hard_mdef - div(magic.hard_mdef * rate, 100)
    ClassicDefense.apply_mdef(damage, %{hard_mdef: hard, soft_mdef: magic.soft_mdef})
  end

  defp first_holy(damage, inputs), do: inputs.element_step.(max(damage, 1), :holy)

  defp finish(_damage, %{caster_ref: {type, id}, target_ref: {type, id}}) when type != :player,
    do: 0

  defp finish(holy, inputs) do
    if inputs.caster_ref == inputs.target_ref,
      do: div(holy, 2),
      else: inputs.element_step.(holy, :holy)
  end
end
