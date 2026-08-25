defmodule Aesir.ZoneServer.Mmo.Mechanics.Elements.PreRenewal do
  @moduledoc """
  Pre-renewal element damage modifiers.

  The static table is transcribed from `rAthena db/pre-re/attr_fix.yml`.
  Each level contains attack-element rows and defense-element columns. Integer percentages are
  divided by 100 at lookup; the canonical `Dark` element is exposed as `:shadow`.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.Elements

  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers

  @element_indexes %{
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

  @tables {
    # Defense level 1
    {
      {100, 100, 100, 100, 100, 100, 100, 100, 25, 100},
      {100, 25, 100, 150, 50, 100, 75, 100, 100, 100},
      {100, 100, 100, 50, 150, 100, 75, 100, 100, 100},
      {100, 50, 150, 25, 100, 100, 75, 100, 100, 125},
      {100, 175, 50, 100, 25, 100, 75, 100, 100, 100},
      {100, 100, 125, 125, 125, 0, 75, 50, 100, -25},
      {100, 100, 100, 100, 100, 100, 0, 125, 100, 150},
      {100, 100, 100, 100, 100, 50, 125, 0, 100, -25},
      {25, 100, 100, 100, 100, 100, 75, 75, 125, 100},
      {100, 100, 100, 100, 100, 50, 100, 0, 100, 0}
    },
    # Defense level 2
    {
      {100, 100, 100, 100, 100, 100, 100, 100, 25, 100},
      {100, 0, 100, 175, 25, 100, 50, 75, 100, 100},
      {100, 100, 50, 25, 175, 100, 50, 75, 100, 100},
      {100, 25, 175, 0, 100, 100, 50, 75, 100, 150},
      {100, 175, 25, 100, 0, 100, 50, 75, 100, 100},
      {100, 75, 125, 125, 125, 0, 50, 25, 75, -50},
      {100, 100, 100, 100, 100, 100, -25, 150, 100, 175},
      {100, 100, 100, 100, 100, 25, 150, -25, 100, -50},
      {0, 75, 75, 75, 75, 75, 50, 50, 150, 125},
      {100, 75, 75, 75, 75, 25, 125, 0, 100, 0}
    },
    # Defense level 3
    {
      {100, 100, 100, 100, 100, 100, 100, 100, 0, 100},
      {100, -25, 100, 200, 0, 100, 25, 50, 100, 125},
      {100, 100, 0, 0, 200, 100, 25, 50, 100, 75},
      {100, 0, 200, -25, 100, 100, 25, 50, 100, 175},
      {100, 200, 0, 100, -25, 100, 25, 50, 100, 100},
      {100, 50, 100, 100, 100, 0, 25, 0, 50, -75},
      {100, 100, 100, 100, 100, 125, -50, 175, 100, 200},
      {100, 100, 100, 100, 100, 0, 175, -50, 100, -75},
      {0, 50, 50, 50, 50, 50, 25, 25, 175, 150},
      {100, 50, 50, 50, 50, 0, 150, 0, 100, 0}
    },
    # Defense level 4
    {
      {100, 100, 100, 100, 100, 100, 100, 100, 0, 100},
      {100, -50, 100, 200, 0, 75, 0, 25, 100, 150},
      {100, 100, -25, 0, 200, 75, 0, 25, 100, 50},
      {100, 0, 200, -50, 100, 75, 0, 25, 100, 200},
      {100, 200, 0, 100, -50, 75, 0, 25, 100, 100},
      {100, 25, 75, 75, 75, 0, 0, -25, 25, -100},
      {100, 75, 75, 75, 75, 125, -100, 200, 100, 200},
      {100, 75, 75, 75, 75, -25, 200, -100, 100, -100},
      {0, 25, 25, 25, 25, 25, 0, 0, 200, 175},
      {100, 25, 25, 25, 25, -25, 175, 0, 100, 0}
    }
  }

  @impl true
  @spec get_modifier(
          ElementModifiers.element(),
          ElementModifiers.element(),
          ElementModifiers.element_level(),
          number()
        ) :: float()
  def get_modifier(attack_element, defense_element, defense_level, ratio_bonus) do
    base_modifier(attack_element, defense_element, defense_level) + ratio_bonus / 100
  end

  defp base_modifier(attack_element, defense_element, defense_level)
       when defense_level in 1..4 do
    case {@element_indexes[attack_element], @element_indexes[defense_element]} do
      {nil, _defense_index} ->
        1.0

      {_attack_index, nil} ->
        1.0

      {attack_index, defense_index} ->
        @tables
        |> elem(defense_level - 1)
        |> elem(attack_index)
        |> elem(defense_index)
        |> Kernel./(100)
    end
  end

  defp base_modifier(_attack_element, _defense_element, _defense_level), do: 1.0
end
