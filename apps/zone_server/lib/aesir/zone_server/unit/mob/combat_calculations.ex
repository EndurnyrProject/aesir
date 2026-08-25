defmodule Aesir.ZoneServer.Unit.Mob.CombatCalculations do
  @moduledoc """
  Mob-specific combat calculation facade for the active ruleset.

  ## Key Features

  - Runtime ruleset dispatch
  - Level and base-stat scaling
  """

  @behaviour Aesir.ZoneServer.Unit.CombatCalculations

  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition

  @typedoc "Mob definition structure used for calculations"
  @type mob_data :: MobDefinition.t()

  @doc """
  Calculates the mob HIT stat under the active ruleset.

  Renewal adds its combat baseline to level and DEX; classic uses level and DEX directly.
  """
  @impl true
  @spec calculate_hit(mob_data()) :: integer()
  def calculate_hit(%MobDefinition{} = mob_data) do
    Mechanics.mob_formulas().calculate_hit(mob_data)
  end

  @doc """
  Calculates the mob FLEE stat under the active ruleset.

  Renewal adds its combat baseline to level and AGI; classic uses level and AGI directly.
  """
  @impl true
  @spec calculate_flee(mob_data()) :: integer()
  def calculate_flee(%MobDefinition{} = mob_data) do
    Mechanics.mob_formulas().calculate_flee(mob_data)
  end

  @doc """
  Calculates the mob perfect-dodge stat.

  ## Formula

      perfect_dodge = trunc(luk / 5)
  """
  @impl true
  @spec calculate_perfect_dodge(mob_data()) :: integer()
  def calculate_perfect_dodge(%MobDefinition{} = mob_data) do
    Mechanics.mob_formulas().calculate_perfect_dodge(mob_data)
  end

  @doc """
  Calculates mob ASPD from attack delay.

  ## Formula

      aspd = max(100, 200 - attack_delay / 10)
  """
  @impl true
  @spec calculate_aspd(mob_data()) :: integer()
  def calculate_aspd(%MobDefinition{} = mob_data) do
    Mechanics.mob_formulas().calculate_aspd(mob_data)
  end

  @doc """
  Calculates the mob base attack stat from its database ATK.

  Damage variance is applied later in the combat system.
  """
  @impl true
  @spec calculate_base_attack(mob_data()) :: integer()
  def calculate_base_attack(%MobDefinition{} = mob_data) do
    Mechanics.mob_formulas().calculate_base_attack(mob_data)
  end

  @doc "Calculates the mob hard-DEF stat from its database DEF."
  @impl true
  @spec calculate_defense(mob_data()) :: integer()
  def calculate_defense(%MobDefinition{} = mob_data) do
    Mechanics.mob_formulas().calculate_defense(mob_data)
  end

  @doc "Calculates the mob soft-DEF stat under the active ruleset."
  @spec calculate_soft_defense(mob_data()) :: integer()
  def calculate_soft_defense(%MobDefinition{} = mob_data) do
    Mechanics.mob_formulas().calculate_soft_defense(mob_data)
  end

  @doc "Calculates the mob magic attack stat from its database MATK."
  @spec calculate_magic_attack(mob_data()) :: integer()
  def calculate_magic_attack(%MobDefinition{} = mob_data) do
    Mechanics.mob_formulas().calculate_magic_attack(mob_data)
  end

  @doc "Calculates the mob hard-MDEF stat from its database MDEF."
  @spec calculate_magic_defense(mob_data()) :: integer()
  def calculate_magic_defense(%MobDefinition{} = mob_data) do
    Mechanics.mob_formulas().calculate_magic_defense(mob_data)
  end

  @doc "Calculates the mob soft-MDEF stat under the active ruleset."
  @spec calculate_soft_mdef(mob_data()) :: integer()
  def calculate_soft_mdef(%MobDefinition{} = mob_data) do
    Mechanics.mob_formulas().calculate_soft_mdef(mob_data)
  end
end
