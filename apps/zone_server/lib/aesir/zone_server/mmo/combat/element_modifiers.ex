defmodule Aesir.ZoneServer.Mmo.Combat.ElementModifiers do
  @moduledoc """
  Public element interaction API.

  A modifier of `1.0` deals normal damage, values above or below it increase or reduce damage,
  and `0.0` is immunity. Element fields add percentage points to Renewal's table ratio. Classic
  fields multiply damage before the table modifier, represented here by multiplying both factors.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics

  @typedoc "Element used by attacks and defenses."
  @type element ::
          :neutral
          | :water
          | :earth
          | :fire
          | :wind
          | :poison
          | :holy
          | :shadow
          | :ghost
          | :undead
  @typedoc "Defense element level."
  @type element_level :: 1..4

  @element_ids %{
    neutral: 0,
    water: 1,
    earth: 2,
    fire: 3,
    wind: 4,
    poison: 5,
    holy: 6,
    shadow: 7,
    ghost: 8,
    undead: 9
  }

  @doc """
  Returns the numeric wire id for an element atom.

  Unknown elements fall back to `0` (neutral).
  """
  @spec id(element()) :: non_neg_integer()
  def id(element), do: Map.get(@element_ids, element, 0)

  @doc """
  Returns the damage modifier for an attack and defense element.

  `defense_level` defaults to `1`. `ratio_bonus` defaults to `0`; each mode composes it with the
  selected table row according to that ruleset.
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
