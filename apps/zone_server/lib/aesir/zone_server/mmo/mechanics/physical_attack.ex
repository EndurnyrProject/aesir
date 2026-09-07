defmodule Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack do
  @moduledoc """
  Pure player physical-attack arithmetic over captured combat inputs.

  Implementations return inclusive weapon bounds; the shared coordinator owns
  random draws, status lookups and hit delivery.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics.Defense

  @typedoc "Effective player attack inputs captured during stat recomputation."
  @type snapshot :: %{
          status_atk: integer(),
          flat_atk: integer(),
          mastery_atk: integer(),
          str: integer(),
          dex: integer()
        }

  @typedoc "Selected weapon and effective stats used for its damage roll."
  @type weapon_inputs :: %{
          base_atk: non_neg_integer(),
          refine_atk: non_neg_integer(),
          weapon_level: non_neg_integer(),
          primary_stat: integer(),
          dex: integer(),
          arrow?: boolean(),
          critical?: boolean(),
          max_weapon_damage?: boolean()
        }

  @typedoc "Hand-local damage inputs; Renewal's weapon roll already includes refine."
  @type parts :: %{
          status_atk: integer(),
          flat_atk: integer(),
          weapon_atk: integer(),
          refine_atk: non_neg_integer(),
          overrefine_atk: non_neg_integer(),
          mastery_atk: integer(),
          hand: :right_hand | :left_hand,
          source: :weapon | :shield
        }

  @typedoc "Ordered attacker cardfix families, represented as additive percentage points."
  @type attack_rates :: %{race_class: integer(), element: integer(), size: integer()}

  @typedoc "Defender cardfix channels, separated from skill-specific reduction."
  @type defender_rates :: %{
          race_class: integer(),
          monster: integer(),
          element: integer(),
          size: integer(),
          long_def: integer(),
          ranged: integer()
        }

  @typedoc "Captured modifier and defense values; implementations perform no lookups."
  @type context :: %{
          optional(:defense_mode) => :normal | :simple,
          optional(:weapon_bonus) => integer(),
          optional(:flat_bonus) => integer(),
          optional(:atk_rate) => integer(),
          optional(:damage_multiplier) => number(),
          optional(:global_race_rate) => integer(),
          optional(:long_atk_rate) => integer(),
          optional(:short_atk_rate) => integer(),
          optional(:defender_rates) => defender_rates(),
          optional(:res) => integer(),
          optional(:physical_reduction) => integer(),
          optional(:critical?) => boolean(),
          optional(:crit_atk_rate) => integer(),
          optional(:crate) => integer(),
          optional(:skill_id) => pos_integer() | nil,
          optional(:skill_ratio) => integer(),
          optional(:bonus_atk) => integer(),
          optional(:skill_atk_rate) => integer(),
          optional(:skill_taken_rate) => integer(),
          optional(:patk) => integer(),
          optional(:equipment_atk_rate) => integer(),
          size_rate: integer(),
          weapon_element: number(),
          neutral_element: number(),
          attacker_rates: attack_rates(),
          defense: Defense.physical_context()
        }

  @doc "Calculates one physical hit from already rolled components and captured modifiers."
  @callback calculate(parts(), context()) :: integer()

  @doc "Applies the three attacker cardfix families in their fixed order."
  @spec attacker_cardfix(integer(), attack_rates()) :: integer()
  def attacker_cardfix(damage, rates) do
    damage
    |> rate(rates.race_class)
    |> rate(rates.element)
    |> rate(rates.size)
  end

  @doc "Applies defender families without creating damage from an empty component."
  @spec defender_cardfix(integer(), defender_rates() | nil, :weapon | :status) :: integer()
  def defender_cardfix(damage, nil, _channel), do: damage

  def defender_cardfix(damage, rates, channel) do
    element_rate = if channel == :weapon, do: rates.element, else: 0

    damage
    |> taken_rate(rates.race_class)
    |> taken_rate(rates.monster)
    |> taken_rate(element_rate)
    |> taken_rate(rates.size)
    |> taken_rate(rates.long_def)
    |> rate(max(rates.ranged, -100))
  end

  @doc "Applies shared status attack-rate and generic damage-multiplier channels."
  @spec status_damage(integer(), context()) :: integer()
  def status_damage(damage, context) do
    damage
    |> rate(Map.get(context, :atk_rate, 0))
    |> Kernel.*(1 + Map.get(context, :damage_multiplier, 0))
    |> trunc()
  end

  @doc "Applies the existing short- and long-attack channels in their fixed order."
  @spec range_damage(integer(), context()) :: integer()
  def range_damage(damage, context) do
    damage
    |> rate(Map.get(context, :long_atk_rate, 0))
    |> rate(Map.get(context, :short_atk_rate, 0))
  end

  @doc "Applies the selected existing DEF formula or the restricted flat-defense recipe."
  @spec apply_defense(number(), context(), module()) :: number()
  def apply_defense(damage, %{defense_mode: :simple, defense: defense}, _implementation) do
    damage - defense.hard_def - defense.soft_def
  end

  def apply_defense(damage, context, implementation) do
    implementation.apply_def(damage, context.defense)
  end

  @doc "Applies the final physical reduction and minimum-damage convention."
  @spec finish(number(), context()) :: pos_integer()
  def finish(damage, context) do
    reduction = context |> Map.get(:physical_reduction, 0) |> max(0) |> min(100)
    max(1, rate(damage, -reduction))
  end

  defp taken_rate(damage, reduction), do: div(damage * max(100 - reduction, 0), 100)

  @doc "Applies additive percentage points with integer truncation."
  @spec rate(number(), integer()) :: integer()
  def rate(damage, rate), do: div(trunc(damage) * (100 + rate), 100)

  @doc "Returns the unmodified sum of the selected hand's attack components."
  @callback base_attack(parts()) :: integer()

  @doc "Returns inclusive bounds for one selected weapon, without rolling."
  @callback weapon_bounds(weapon_inputs()) :: {non_neg_integer(), non_neg_integer()}
end
