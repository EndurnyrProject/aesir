defmodule Aesir.ZoneServer.Mmo.Combat.SizeModifiers do
  @moduledoc """
  Size-based damage modifier table based on rAthena implementation.

  This module handles the damage modifications that occur when different
  sized entities attack each other. In Ragnarok Online, weapon size
  affects damage output.

  Size types:
  - :small - Small monsters and some weapons
  - :medium - Human-sized entities and most weapons  
  - :large - Large monsters and two-handed weapons

  The modifier system reflects weapon effectiveness vs different sizes:
  - Small weapons are most effective vs small targets
  - Medium weapons are balanced across all sizes
  - Large weapons are most effective vs large targets
  """

  @type size :: :small | :medium | :large

  @doc """
  Gets the damage modifier for attacker size vs defender size.

  ## Parameters
    - attacker_size: Size of the attacking entity/weapon
    - defender_size: Size of the defending target

  ## Returns
    - Float representing the damage modifier
  """
  @spec get_modifier(size(), size()) :: float()
  def get_modifier(attacker_size, defender_size) do
    size_modifier_table(attacker_size, defender_size)
  end

  @doc """
  Gets the default size for players (medium).
  """
  @spec player_size() :: size()
  def player_size, do: :medium

  @doc """
  Gets the weapon size based on weapon type.
  For now, returns medium as default until weapon system is implemented.
  """
  @spec weapon_size(atom()) :: size()
  def weapon_size(_weapon_type), do: :medium

  # Size modifier table from rAthena
  # Values represent damage multiplier when attacker_size attacks defender_size

  # Small attacker (daggers, small weapons)
  defp size_modifier_table(:small, :small), do: 1.0
  defp size_modifier_table(:small, :medium), do: 0.75
  defp size_modifier_table(:small, :large), do: 0.5

  # Medium attacker (swords, most weapons, players)
  defp size_modifier_table(:medium, :small), do: 1.25
  defp size_modifier_table(:medium, :medium), do: 1.0
  defp size_modifier_table(:medium, :large), do: 0.75

  # Large attacker (two-handed weapons, large weapons)
  defp size_modifier_table(:large, :small), do: 1.5
  defp size_modifier_table(:large, :medium), do: 1.25
  defp size_modifier_table(:large, :large), do: 1.0

  # Default case for unknown sizes
  defp size_modifier_table(_, _), do: 1.0
end
