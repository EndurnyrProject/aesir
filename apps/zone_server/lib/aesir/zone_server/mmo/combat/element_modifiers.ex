defmodule Aesir.ZoneServer.Mmo.Combat.ElementModifiers do
  @moduledoc """
  Element damage modifier table based on rAthena implementation.

  This module provides the element interaction matrix that determines
  how much damage different attack elements deal to different defense elements.

  The modifier system works as follows:
  - 1.0 = normal damage
  - > 1.0 = increased damage (weakness)
  - < 1.0 = reduced damage (resistance)
  - 0.0 = immune

  Element levels (1-4) affect the strength of the resistance/weakness.
  """

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
  @type element_level :: 1..4

  @doc """
  Gets the damage modifier for attack element vs defense element.

  ## Parameters
    - attack_element: The element of the attack
    - defense_element: The element of the defending target
    - defense_level: The level of the defense element (1-4)

  ## Returns
    - Float representing the damage modifier
  """
  @spec get_modifier(element(), element(), element_level()) :: float()
  def get_modifier(attack_element, defense_element, defense_level \\ 1) do
    base_modifier = element_table(attack_element, defense_element)
    apply_level_scaling(base_modifier, defense_level)
  end

  # Element interaction table from rAthena
  # Rows = attack element, Columns = defense element

  # Neutral attacks
  defp element_table(:neutral, :neutral), do: 1.0
  defp element_table(:neutral, :water), do: 1.0
  defp element_table(:neutral, :earth), do: 1.0
  defp element_table(:neutral, :fire), do: 1.0
  defp element_table(:neutral, :wind), do: 1.0
  defp element_table(:neutral, :poison), do: 1.0
  defp element_table(:neutral, :holy), do: 1.0
  defp element_table(:neutral, :shadow), do: 1.0
  defp element_table(:neutral, :ghost), do: 0.7
  defp element_table(:neutral, :undead), do: 1.0

  # Water attacks
  defp element_table(:water, :neutral), do: 1.0
  defp element_table(:water, :water), do: 0.25
  defp element_table(:water, :earth), do: 1.0
  defp element_table(:water, :fire), do: 2.0
  defp element_table(:water, :wind), do: 0.9
  defp element_table(:water, :poison), do: 1.0
  defp element_table(:water, :holy), do: 0.75
  defp element_table(:water, :shadow), do: 1.0
  defp element_table(:water, :ghost), do: 0.7
  defp element_table(:water, :undead), do: 1.0

  # Earth attacks
  defp element_table(:earth, :neutral), do: 1.0
  defp element_table(:earth, :water), do: 1.0
  defp element_table(:earth, :earth), do: 0.25
  defp element_table(:earth, :fire), do: 0.9
  defp element_table(:earth, :wind), do: 2.0
  defp element_table(:earth, :poison), do: 1.25
  defp element_table(:earth, :holy), do: 0.75
  defp element_table(:earth, :shadow), do: 1.0
  defp element_table(:earth, :ghost), do: 0.7
  defp element_table(:earth, :undead), do: 1.0

  # Fire attacks
  defp element_table(:fire, :neutral), do: 1.0
  defp element_table(:fire, :water), do: 0.9
  defp element_table(:fire, :earth), do: 2.0
  defp element_table(:fire, :fire), do: 0.25
  defp element_table(:fire, :wind), do: 1.0
  defp element_table(:fire, :poison), do: 1.0
  defp element_table(:fire, :holy), do: 0.75
  defp element_table(:fire, :shadow), do: 1.0
  defp element_table(:fire, :ghost), do: 0.7
  defp element_table(:fire, :undead), do: 1.25

  # Wind attacks
  defp element_table(:wind, :neutral), do: 1.0
  defp element_table(:wind, :water), do: 2.0
  defp element_table(:wind, :earth), do: 0.9
  defp element_table(:wind, :fire), do: 1.0
  defp element_table(:wind, :wind), do: 0.25
  defp element_table(:wind, :poison), do: 1.0
  defp element_table(:wind, :holy), do: 0.75
  defp element_table(:wind, :shadow), do: 1.0
  defp element_table(:wind, :ghost), do: 0.7
  defp element_table(:wind, :undead), do: 1.0

  # Poison attacks
  defp element_table(:poison, :neutral), do: 1.0
  defp element_table(:poison, :water), do: 1.0
  defp element_table(:poison, :earth), do: 0.75
  defp element_table(:poison, :fire), do: 1.0
  defp element_table(:poison, :wind), do: 1.0
  defp element_table(:poison, :poison), do: 0.0
  defp element_table(:poison, :holy), do: 0.5
  defp element_table(:poison, :shadow), do: 0.75
  defp element_table(:poison, :ghost), do: 0.7
  defp element_table(:poison, :undead), do: 0.5

  # Holy attacks
  defp element_table(:holy, :neutral), do: 1.0
  defp element_table(:holy, :water), do: 0.75
  defp element_table(:holy, :earth), do: 0.75
  defp element_table(:holy, :fire), do: 0.75
  defp element_table(:holy, :wind), do: 0.75
  defp element_table(:holy, :poison), do: 1.0
  defp element_table(:holy, :holy), do: 0.0
  defp element_table(:holy, :shadow), do: 1.25
  defp element_table(:holy, :ghost), do: 1.0
  defp element_table(:holy, :undead), do: 1.25

  # Shadow attacks
  defp element_table(:shadow, :neutral), do: 1.0
  defp element_table(:shadow, :water), do: 1.0
  defp element_table(:shadow, :earth), do: 1.0
  defp element_table(:shadow, :fire), do: 1.0
  defp element_table(:shadow, :wind), do: 1.0
  defp element_table(:shadow, :poison), do: 0.75
  defp element_table(:shadow, :holy), do: 1.25
  defp element_table(:shadow, :shadow), do: 0.0
  defp element_table(:shadow, :ghost), do: 0.7
  defp element_table(:shadow, :undead), do: 0.0

  # Ghost attacks
  defp element_table(:ghost, :neutral), do: 0.7
  defp element_table(:ghost, :water), do: 1.0
  defp element_table(:ghost, :earth), do: 1.0
  defp element_table(:ghost, :fire), do: 1.0
  defp element_table(:ghost, :wind), do: 1.0
  defp element_table(:ghost, :poison), do: 1.0
  defp element_table(:ghost, :holy), do: 1.0
  defp element_table(:ghost, :shadow), do: 1.0
  defp element_table(:ghost, :ghost), do: 1.25
  defp element_table(:ghost, :undead), do: 1.0

  # Undead attacks
  defp element_table(:undead, :neutral), do: 1.0
  defp element_table(:undead, :water), do: 1.0
  defp element_table(:undead, :earth), do: 1.0
  defp element_table(:undead, :fire), do: 0.75
  defp element_table(:undead, :wind), do: 1.0
  defp element_table(:undead, :poison), do: 0.5
  defp element_table(:undead, :holy), do: 1.25
  defp element_table(:undead, :shadow), do: 0.0
  defp element_table(:undead, :ghost), do: 1.0
  defp element_table(:undead, :undead), do: 0.0

  # Default case for unknown elements
  defp element_table(_, _), do: 1.0

  # Element level scaling
  # Higher element levels increase resistance/weakness effects
  defp apply_level_scaling(base_modifier, 1), do: base_modifier

  defp apply_level_scaling(base_modifier, 2) when base_modifier < 1.0 do
    base_modifier * 0.8
  end

  defp apply_level_scaling(base_modifier, 2) when base_modifier > 1.0 do
    base_modifier * 1.1
  end

  defp apply_level_scaling(base_modifier, 3) when base_modifier < 1.0 do
    base_modifier * 0.6
  end

  defp apply_level_scaling(base_modifier, 3) when base_modifier > 1.0 do
    base_modifier * 1.2
  end

  defp apply_level_scaling(base_modifier, 4) when base_modifier < 1.0 do
    base_modifier * 0.4
  end

  defp apply_level_scaling(base_modifier, 4) when base_modifier > 1.0 do
    base_modifier * 1.3
  end

  defp apply_level_scaling(base_modifier, _), do: base_modifier
end
