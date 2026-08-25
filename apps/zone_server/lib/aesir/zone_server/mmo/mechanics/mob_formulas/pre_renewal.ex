defmodule Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.PreRenewal do
  @moduledoc """
  Classic mob formulas use unshifted HIT/FLEE and VIT-based soft defenses.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.MobFormulas

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition

  @impl true
  def calculate_hit(%MobDefinition{} = mob_data) do
    mob_data.level + mob_data.stats.dex
  end

  @impl true
  def calculate_flee(%MobDefinition{} = mob_data) do
    mob_data.level + mob_data.stats.agi
  end

  @impl true
  def calculate_perfect_dodge(%MobDefinition{} = mob_data) do
    trunc(mob_data.stats.luk / 5)
  end

  @impl true
  def calculate_aspd(%MobDefinition{} = mob_data) do
    max(100, 200 - div(mob_data.attack_delay, 10))
  end

  @impl true
  def calculate_base_attack(%MobDefinition{} = mob_data) do
    mob_data.atk
  end

  @impl true
  def calculate_defense(%MobDefinition{} = mob_data) do
    mob_data.def
  end

  @impl true
  def calculate_soft_defense(%MobDefinition{} = mob_data), do: mob_data.stats.vit

  @impl true
  def calculate_magic_attack(%MobDefinition{} = mob_data) do
    mob_data.matk
  end

  @impl true
  def calculate_magic_defense(%MobDefinition{} = mob_data) do
    mob_data.mdef
  end

  @impl true
  def calculate_soft_mdef(%MobDefinition{} = mob_data) do
    mob_data.stats.int + div(mob_data.stats.vit, 2)
  end
end
