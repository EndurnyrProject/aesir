defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal.Formula do
  @moduledoc """
  Heal's pure per-mode amount, shared by the restorative cast and the offensive
  cast against undead. Inputs are already read and rolled by the caller, so the
  formula is deterministic.

  Renewal: the base is `(base level + INT) / 5 * 30 * skill level / 10`. An
  offensive cast halves that base first. Equipment heal power is then a
  percentage of the base, the caster's MATK band is added flat on top (it is
  never scaled by heal power and never halved), and the trait heal bonus is a
  final percentage of the whole amount. A restorative heal never lands below one
  point.

  Pre-renewal: the base is `(base level + INT) / 8 * (4 + skill level * 8)`,
  with no MATK term and no trait bonus at all. An offensive cast halves that
  base, equipment heal power is a percentage of it, and that is the whole
  amount.

  Heal bonuses: in renewal the caster's Meditatio bonus and the target's
  Assumptio bonus join equipment heal power in one additive percentage. In
  pre-renewal Meditatio is its own percentage step applied before equipment
  heal power, and Assumptio adds nothing. Both bonuses default to zero.

  The classic base is a coarser ladder that peaks higher at full skill
  level but ignores the caster's magic attack entirely, so Heal scales with the
  caster's gear in renewal and only with level and INT in pre-renewal.
  """

  alias Aesir.Commons.GameMode

  @typedoc "Caster-derived amounts, already read and rolled by the caller."
  @type inputs :: %{
          required(:base_level) => pos_integer(),
          required(:int) => non_neg_integer(),
          required(:level) => pos_integer(),
          required(:matk_roll) => non_neg_integer(),
          required(:heal_power) => integer(),
          required(:hplus) => integer(),
          required(:offensive?) => boolean(),
          optional(:caster_heal_bonus) => integer(),
          optional(:target_heal_bonus) => integer()
        }

  @doc "Returns the heal (or offensive holy hit) amount for the given mode."
  @spec calculate(GameMode.t(), inputs()) :: non_neg_integer()
  def calculate(:renewal, inputs) do
    base =
      div(div(inputs.base_level + inputs.int, 5) * 30 * inputs.level, 10)
      |> halve_when_offensive(inputs)
      |> apply_percentage(
        inputs.heal_power + bonus(inputs, :caster_heal_bonus) +
          bonus(inputs, :target_heal_bonus)
      )

    total = base + inputs.matk_roll
    amount = total + div(total * inputs.hplus, 100)

    if inputs.offensive?, do: amount, else: max(amount, 1)
  end

  def calculate(:pre_renewal, inputs) do
    (div(inputs.base_level + inputs.int, 8) * (4 + inputs.level * 8))
    |> halve_when_offensive(inputs)
    |> apply_percentage(bonus(inputs, :caster_heal_bonus))
    |> apply_percentage(inputs.heal_power)
  end

  defp bonus(inputs, key), do: Map.get(inputs, key, 0)

  @spec halve_when_offensive(non_neg_integer(), inputs()) :: non_neg_integer()
  defp halve_when_offensive(amount, %{offensive?: true}), do: div(amount, 2)
  defp halve_when_offensive(amount, _inputs), do: amount

  @spec apply_percentage(non_neg_integer(), integer()) :: non_neg_integer()
  defp apply_percentage(amount, rate), do: amount + div(amount * rate, 100)
end
