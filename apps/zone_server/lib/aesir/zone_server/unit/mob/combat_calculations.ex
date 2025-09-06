defmodule Aesir.ZoneServer.Unit.Mob.CombatCalculations do
  @moduledoc """
  Mob-specific combat calculation implementation.

  ## Key Features

  - Performance-optimized simple formulas
  - Level and base stat scaling
  """

  @behaviour Aesir.ZoneServer.Unit.CombatCalculations

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition

  @typedoc "Mob definition structure used for calculations"
  @type mob_data :: MobDefinition.t()

  @doc """
  Calculates mob hit stat using simplified rAthena formula.

  ## Formula
  hit = level + dex
  """
  @impl true
  @spec calculate_hit(mob_data()) :: integer()
  def calculate_hit(%MobDefinition{} = mob_data) do
    mob_data.level + mob_data.stats.dex
  end

  @doc """
  Calculates mob flee stat

  ## Formula
  flee = level + agi
  """
  @impl true
  @spec calculate_flee(mob_data()) :: integer()
  def calculate_flee(%MobDefinition{} = mob_data) do
    mob_data.level + mob_data.stats.agi
  end

  @doc """
  Calculates mob perfect dodge stat

  ## Formula
  perfect_dodge = luk / 5
  """
  @impl true
  @spec calculate_perfect_dodge(mob_data()) :: integer()
  def calculate_perfect_dodge(%MobDefinition{} = mob_data) do
    # Same base formula as players: luk/5
    trunc(mob_data.stats.luk / 5)
  end

  @doc """
  Calculates mob ASPD from attack delay.

  ## Formula
  aspd = max(100, 200 - attack_delay/10)

  Converts attack delay to ASPD format for consistency with player system.
  """
  @impl true
  @spec calculate_aspd(mob_data()) :: integer()
  def calculate_aspd(%MobDefinition{} = mob_data) do
    max(100, 200 - div(mob_data.attack_delay, 10))
  end

  @doc """
  Calculates mob base attack stat.

  ## Formula
  base_atk = atk_min (using minimum attack value)

  Mobs have predefined attack ranges, we use the minimum for base calculations.
  Variance is handled elsewhere in the combat system.
  """
  @impl true
  @spec calculate_base_attack(mob_data()) :: integer()
  def calculate_base_attack(%MobDefinition{} = mob_data) do
    mob_data.atk_min
  end

  @doc """
  Calculates mob defense stat.

  ## Formula
  defense = def (direct from mob definition)
  """
  @impl true
  @spec calculate_defense(mob_data()) :: integer()
  def calculate_defense(%MobDefinition{} = mob_data) do
    mob_data.def
  end
end
