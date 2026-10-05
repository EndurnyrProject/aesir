defmodule Aesir.ZoneServer.Mmo.Combat.ElementModifiers do
  @moduledoc """
  Public element interaction API for the active game mode.

  Ratios are integer percentages from the mode's exact attribute table: `100` deals normal damage,
  `0` is immunity and a negative ratio can heal. `adjust_damage/2` applies the ratio, together with
  ordered field and status bonuses, using the mode's integer arithmetic.
  """

  alias Aesir.ZoneServer.Mmo.Element
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.Mechanics.Elements

  @typedoc "Element used by attacks and defenses."
  @type element :: Element.t()
  @typedoc "Defense element level."
  @type element_level :: Element.level()

  @doc """
  Returns the numeric wire id for an element atom.

  Unknown elements fall back to `0` (neutral).
  """
  @spec id(element()) :: non_neg_integer()
  defdelegate id(element), to: Element

  @doc """
  Returns the active mode's table percentage for an attack against a defense element and level.

  Unknown elements or levels return `100`.
  """
  @spec ratio(element(), element(), element_level()) :: integer()
  def ratio(attack_element, defense_element, defense_level) do
    Mechanics.elements().ratio(attack_element, defense_element, defense_level)
  end

  @doc """
  Applies one attribute adjustment to integer `damage` with the active mode's arithmetic.
  """
  @spec adjust_damage(integer(), Elements.adjustment()) :: integer()
  def adjust_damage(damage, adjustment) do
    Mechanics.elements().adjust_damage(damage, adjustment)
  end

  @doc """
  Returns the table ratio as a coefficient, with `ratio_bonus` composed by the active mode.

  `defense_level` defaults to `1` and `ratio_bonus` to `0`. Renewal adds the bonus to the ratio;
  classic scales the ratio by the bonus percentage.
  """
  @spec get_modifier(element(), element(), element_level(), number()) :: float()
  def get_modifier(attack_element, defense_element, defense_level \\ 1, ratio_bonus \\ 0) do
    Mechanics.elements().get_modifier(
      attack_element,
      defense_element,
      defense_level,
      ratio_bonus
    )
  end
end
