defmodule Aesir.ZoneServer.Mmo.Mechanics.Elements.Renewal do
  @moduledoc """
  Renewal element damage.

  Each defense level has its own table. Field and status bonuses add percentage points to the
  table ratio, and the final step subtracts the truncated reduction from the damage
  (`damage - (damage * (100 - ratio)) / 100`), so a reduction never rounds damage to zero unless
  the ratio is zero.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.Elements

  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Mechanics.Elements

  @tables {
    # Defense level 1
    {
      {100, 100, 100, 100, 100, 100, 100, 100, 90, 100},
      {100, 25, 100, 150, 90, 150, 100, 100, 100, 100},
      {100, 100, 25, 90, 150, 150, 100, 100, 100, 100},
      {100, 90, 150, 25, 100, 150, 100, 100, 100, 125},
      {100, 150, 90, 100, 25, 150, 100, 100, 100, 100},
      {100, 150, 150, 150, 150, 0, 75, 75, 75, 75},
      {100, 100, 100, 100, 100, 75, 0, 125, 100, 125},
      {100, 100, 100, 100, 100, 75, 125, 0, 100, 0},
      {90, 100, 100, 100, 100, 75, 90, 90, 125, 100},
      {100, 100, 100, 90, 100, 75, 125, 0, 100, 0}
    },
    # Defense level 2
    {
      {100, 100, 100, 100, 100, 100, 100, 100, 70, 100},
      {100, 0, 100, 175, 80, 150, 100, 100, 100, 100},
      {100, 100, 0, 80, 175, 150, 100, 100, 100, 100},
      {100, 80, 175, 0, 100, 150, 100, 100, 100, 150},
      {100, 175, 80, 100, 0, 150, 100, 100, 100, 100},
      {100, 150, 150, 150, 150, 0, 75, 75, 75, 50},
      {100, 100, 100, 100, 100, 75, 0, 150, 100, 150},
      {100, 100, 100, 100, 100, 75, 150, 0, 100, 0},
      {70, 100, 100, 100, 100, 75, 80, 80, 150, 125},
      {100, 100, 100, 80, 100, 50, 150, 0, 125, 0}
    },
    # Defense level 3
    {
      {100, 100, 100, 100, 100, 100, 100, 100, 50, 100},
      {100, 0, 100, 200, 70, 125, 100, 100, 100, 100},
      {100, 100, 0, 70, 200, 125, 100, 100, 100, 100},
      {100, 70, 200, 0, 100, 125, 100, 100, 100, 175},
      {100, 200, 70, 100, 0, 125, 100, 100, 100, 100},
      {100, 125, 125, 125, 125, 0, 50, 50, 50, 25},
      {100, 100, 100, 100, 100, 50, 0, 175, 100, 175},
      {100, 100, 100, 100, 100, 50, 175, 0, 100, 0},
      {50, 100, 100, 100, 100, 50, 70, 70, 175, 150},
      {100, 100, 100, 70, 100, 25, 175, 0, 150, 0}
    },
    # Defense level 4
    {
      {100, 100, 100, 100, 100, 100, 100, 100, 0, 100},
      {100, 0, 100, 200, 60, 125, 100, 100, 100, 100},
      {100, 100, 0, 60, 200, 125, 100, 100, 100, 100},
      {100, 60, 200, 0, 100, 125, 100, 100, 100, 200},
      {100, 200, 60, 100, 0, 125, 100, 100, 100, 100},
      {100, 125, 125, 125, 125, 0, 50, 50, 50, 0},
      {100, 100, 100, 100, 100, 50, 0, 200, 100, 200},
      {100, 100, 100, 100, 100, 50, 200, 0, 100, 0},
      {0, 100, 100, 100, 100, 50, 60, 60, 200, 175},
      {100, 100, 100, 60, 100, 0, 200, 0, 175, 0}
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
        ratio =
          adjustment.modifiers
          |> Enum.reduce(table_ratio, fn {_name, points}, acc -> acc + points end)
          |> Elements.final_ratio(adjustment)

        damage - div(damage * (100 - ratio), 100)
    end
  end

  @doc """
  Returns the table ratio plus `ratio_bonus` points as a coefficient.

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
    (ratio(attack_element, defense_element, defense_level) + ratio_bonus) / 100
  end
end
