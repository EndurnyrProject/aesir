defmodule Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack do
  @moduledoc """
  Pure player physical-attack arithmetic over captured combat inputs.

  Implementations return inclusive weapon bounds; the shared coordinator owns
  random draws, status lookups and hit delivery.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics.Defense
  alias Aesir.ZoneServer.Mmo.Mechanics.MagicDamage

  @typedoc """
  Effective player attack inputs captured during stat recomputation.

  `mastery_atk` is every passive ATK plus the right-hand Star Crumb bonus;
  `weapon_mastery_atk` is only the weapon masteries' part of it (for the
  left hand's weapon in `left_weapon_mastery_atk`), `star_atk` and
  `left_star_atk` each hand's Star Crumb bonus, and `weapon_research_atk` and
  `hilt_binding_atk` those two passives' ATK.
  """
  @type snapshot :: %{
          optional(:weapon_mastery_atk) => integer(),
          optional(:left_weapon_mastery_atk) => integer(),
          optional(:star_atk) => integer(),
          optional(:left_star_atk) => integer(),
          optional(:weapon_research_atk) => integer(),
          optional(:hilt_binding_atk) => integer(),
          status_atk: integer(),
          flat_atk: integer(),
          mastery_atk: integer(),
          str: integer(),
          dex: integer()
        }

  @typedoc """
  Selected weapon and effective stats used for its damage roll. `status_watk`
  is the status weapon ATK the hand takes: it raises the classic maximum and
  shifts the renewal centre, never the renewal variance.
  """
  @type weapon_inputs :: %{
          optional(:status_watk) => integer(),
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

  @typedoc """
  The target's card reductions in product order: `weapon` for the weapon and
  equipment components, `status` (without the element resists) for renewal's
  status and mastery components. `nil` when the target has no cards to apply
  (it is not a player).
  """
  @type defender_cards :: %{weapon: [integer()], status: [integer()]} | nil

  @typedoc "Captured modifier and defense values; implementations perform no lookups."
  @type context :: %{
          optional(:defense_mode) => :normal | :simple | :ignore | :soft_only,
          optional(:flat_bonus) => integer(),
          optional(:atk_rate) => integer(),
          optional(:status_skill_ratio) => integer(),
          optional(:post_defense_atk) => integer(),
          optional(:base_atk_rate) => integer(),
          optional(:damage_multiplier) => number(),
          optional(:long_atk_rate) => integer(),
          optional(:short_atk_rate) => integer(),
          optional(:defender_cards) => defender_cards(),
          optional(:res) => integer(),
          optional(:critical?) => boolean(),
          optional(:crit_atk_rate) => integer(),
          optional(:crit_def_rate) => integer(),
          optional(:non_crit_atk_rate) => integer(),
          optional(:ignore_noncrit_atk_bonus) => boolean(),
          optional(:crate) => integer(),
          optional(:skill_id) => pos_integer() | nil,
          optional(:skill_ratio) => integer(),
          optional(:bonus_atk) => integer(),
          optional(:skill_atk_rate) => integer(),
          optional(:skill_taken_rate) => integer(),
          optional(:patk) => integer(),
          optional(:equipment_atk_rate) => integer(),
          optional(:stave_matk) => non_neg_integer(),
          optional(:edp_level) => non_neg_integer(),
          optional(:katar_atk_rate) => non_neg_integer(),
          optional(:watk_element_rate) => integer(),
          size_rate: integer(),
          attacker_cards: [integer()],
          defense: Defense.physical_context()
        }

  @doc """
  Applies the attacker's card percentages as one per-mille factor: each
  percentage multiplies the factor in order, truncating, and the damage takes
  the factor once.
  """
  @spec attacker_cardfix(integer(), [integer()]) :: integer()
  def attacker_cardfix(damage, cards), do: cardfix(damage, cards, 1)

  @doc """
  Applies the target's card reductions as one per-mille factor, without
  creating damage from an empty component. `nil` applies nothing.
  """
  @spec defender_cardfix(integer(), [integer()] | nil) :: integer()
  def defender_cardfix(damage, nil), do: damage
  def defender_cardfix(damage, cards), do: cardfix(damage, cards, -1)

  defp cardfix(damage, cards, sign) do
    factor = Enum.reduce(cards, 1000, &MagicDamage.factor(&2, sign * &1))
    MagicDamage.apply_factor(damage, factor)
  end

  @doc """
  Applies the ATK percent (`:atk_rate`, its points over 100) as one truncating
  product, then the generic damage-multiplier channel. Classic's stage after the
  skill ratio; renewal folds the percent into the ratio instead.
  """
  @spec status_damage(integer(), context()) :: integer()
  def status_damage(damage, context) do
    damage
    |> rate(Map.get(context, :atk_rate, 0))
    |> damage_multiplier(context)
  end

  @doc "Applies the generic damage-multiplier channel."
  @spec damage_multiplier(number(), context()) :: integer()
  def damage_multiplier(damage, context),
    do: trunc(damage * (1 + Map.get(context, :damage_multiplier, 0)))

  @doc """
  The skill ratio with the status ratio adds (Over Thrust, Frenzy) that the
  source sums into it, for every attack including a normal one.
  """
  @spec skill_ratio(context()) :: integer()
  def skill_ratio(context),
    do: Map.get(context, :skill_ratio, 100) + Map.get(context, :status_skill_ratio, 0)

  @doc "Adds the short- and long-attack rates the hit's range selected, in that order."
  @spec range_damage(integer(), %{
          optional(:short_atk_rate) => integer(),
          optional(:long_atk_rate) => integer(),
          optional(atom()) => term()
        }) :: integer()
  def range_damage(damage, context) do
    damage
    |> add_rate(Map.get(context, :short_atk_rate, 0))
    |> add_rate(Map.get(context, :long_atk_rate, 0))
  end

  @doc "Applies the selected existing DEF formula or the restricted flat-defense recipe."
  @spec apply_defense(number(), context(), module()) :: number()
  def apply_defense(damage, %{defense_mode: :simple, defense: defense}, _implementation) do
    damage - defense.hard_def - defense.soft_def
  end

  def apply_defense(damage, %{defense_mode: :ignore}, _implementation), do: damage

  def apply_defense(damage, %{defense_mode: :soft_only, defense: defense} = context, _impl),
    do: damage - div(defense.soft_def * Map.get(context, :skill_ratio, 100), 100)

  def apply_defense(damage, context, implementation) do
    implementation.apply_def(damage, context.defense)
  end

  @doc """
  Adds a percentage of the damage, truncating the added amount toward zero
  (the reference `ATK_ADDRATE`).
  """
  @spec add_rate(number(), integer()) :: integer()
  def add_rate(damage, rate), do: trunc(damage) + div(trunc(damage) * rate, 100)

  @doc "Applies additive percentage points with integer truncation."
  @spec rate(number(), integer()) :: integer()
  def rate(damage, rate), do: div(trunc(damage) * (100 + rate), 100)

  @doc "Returns the unmodified sum of the selected hand's attack components."
  @callback base_attack(parts()) :: integer()

  @doc "Returns inclusive bounds for one selected weapon, without rolling."
  @callback weapon_bounds(weapon_inputs()) :: {non_neg_integer(), non_neg_integer()}
end
