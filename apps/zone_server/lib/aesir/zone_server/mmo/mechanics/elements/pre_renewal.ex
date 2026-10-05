defmodule Aesir.ZoneServer.Mmo.Mechanics.Elements.PreRenewal do
  @moduledoc """
  Pre-renewal element damage modifiers.

  Each defense level has its own attack-element rows and defense-element columns; the canonical
  dark element is exposed as `:shadow`. Field and status bonuses each add their truncated
  percentage to the running damage before the table step, which truncates
  `damage * ratio / 100`.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.Elements

  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Mechanics.Elements

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
  @spec ratio(
          ElementModifiers.element(),
          ElementModifiers.element(),
          ElementModifiers.element_level()
        ) :: integer()
  def ratio(attack_element, defense_element, defense_level) do
    Elements.lookup(@tables, attack_element, defense_element, defense_level) || 100
  end

  @impl true
  @spec adjust_damage(integer(), Elements.adjustment()) :: integer()
  def adjust_damage(damage, adjustment) do
    case Elements.lookup(
           @tables,
           adjustment.attack_element,
           adjustment.defense_element,
           adjustment.defense_level
         ) do
      nil ->
        damage

      table_ratio ->
        damage =
          Enum.reduce(adjustment.modifiers, damage, fn {_name, points}, acc ->
            acc + div(acc * points, 100)
          end)

        div(damage * Elements.final_ratio(table_ratio, adjustment), 100)
    end
  end

  @doc """
  Returns the table ratio scaled by a `ratio_bonus` percentage as a coefficient.

  A preview of the table for callers that do not adjust live damage.
  """
  @impl true
  @spec get_modifier(
          ElementModifiers.element(),
          ElementModifiers.element(),
          ElementModifiers.element_level(),
          number()
        ) :: float()
  def get_modifier(attack_element, defense_element, defense_level, ratio_bonus) do
    ratio(attack_element, defense_element, defense_level) * (100 + ratio_bonus) / 10_000
  end
end
