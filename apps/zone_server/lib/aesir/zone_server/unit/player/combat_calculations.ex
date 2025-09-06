defmodule Aesir.ZoneServer.Unit.Player.CombatCalculations do
  @moduledoc """
  Player-specific combat calculation implementation.

  ## Key Features

  - Equipment and status effect integration
  - Job bonus calculations
  - Base stat effectiveness calculations
  - Multi-source modifier aggregation
  """

  @behaviour Aesir.ZoneServer.Unit.CombatCalculations

  alias Aesir.ZoneServer.Unit.Player.Stats

  @typedoc "Player stats structure used for calculations"
  @type player_stats :: Stats.t()

  @doc """
  Calculates player hit stat

  ## Formula
  Base: DEX + LUK/3 + base_level/4
  Final: base_hit + equipment_bonuses + status_effect_bonuses
  """
  @impl true
  @spec calculate_hit(player_stats()) :: integer()
  def calculate_hit(%Stats{} = stats) do
    effective_dex = Stats.get_effective_stat(stats, :dex)
    effective_luk = Stats.get_effective_stat(stats, :luk)
    base_level = stats.progression.base_level

    # Base hit calculation
    base_hit = trunc(effective_dex + effective_luk / 3 + base_level / 4)

    # Add modifiers from status effects and equipment
    base_hit + Stats.get_status_modifier(stats, :hit)
  end

  @doc """
  Calculates player flee stat

  ## Formula
  Base: AGI + LUK/5 + base_level/4
  Final: base_flee + equipment_bonuses + status_effect_bonuses
  """
  @impl true
  @spec calculate_flee(player_stats()) :: integer()
  def calculate_flee(%Stats{} = stats) do
    effective_agi = Stats.get_effective_stat(stats, :agi)
    effective_luk = Stats.get_effective_stat(stats, :luk)
    base_level = stats.progression.base_level

    # Base flee calculation
    base_flee = trunc(effective_agi + effective_luk / 5 + base_level / 4)

    # Add modifiers from status effects and equipment
    base_flee + Stats.get_status_modifier(stats, :flee)
  end

  @doc """
  Calculates player perfect dodge stat

  ## Formula
  Base: LUK/5
  Final: base_perfect_dodge + equipment_bonuses + status_effect_bonuses

  Note: Client displays this value divided by 10 (flee2/10 format)
  """
  @impl true
  @spec calculate_perfect_dodge(player_stats()) :: integer()
  def calculate_perfect_dodge(%Stats{} = stats) do
    effective_luk = Stats.get_effective_stat(stats, :luk)

    # Base perfect dodge calculation
    base_perfect_dodge = trunc(effective_luk / 5)

    # Add modifiers from status effects and equipment
    base_perfect_dodge + Stats.get_status_modifier(stats, :perfect_dodge)
  end

  @doc """
  Calculates player ASPD

  Includes weapon type bonuses, AGI scaling, and equipment modifiers.
  """
  @impl true
  @spec calculate_aspd(player_stats()) :: integer()
  def calculate_aspd(%Stats{} = stats) do
    Stats.calculate_aspd(stats)
  end

  @doc """
  Calculates player base attack

  ## Formula
  Base: (STR * 2) + (DEX / 5) + (LUK / 3) + base_level/4
  Final: base_atk + weapon_atk + mastery_bonus + equipment_bonuses
  """
  @impl true
  @spec calculate_base_attack(player_stats()) :: integer()
  def calculate_base_attack(%Stats{} = stats) do
    effective_str = Stats.get_effective_stat(stats, :str)
    effective_dex = Stats.get_effective_stat(stats, :dex)
    effective_luk = Stats.get_effective_stat(stats, :luk)
    base_level = stats.progression.base_level

    base_atk =
      effective_str * 2 + div(effective_dex, 5) + div(effective_luk, 3) + div(base_level, 4)

    base_atk + Stats.get_status_modifier(stats, :atk)
  end

  @doc """
  Calculates player defense stat.

  Includes both hard defense (equipment) and soft defense (VIT-based).
  """
  @impl true
  @spec calculate_defense(player_stats()) :: integer()
  def calculate_defense(%Stats{} = stats) do
    effective_vit = Stats.get_effective_stat(stats, :vit)

    # Hard defense from equipment/base stats
    hard_def = Stats.get_status_modifier(stats, :def)

    # Soft defense: VIT + VIT/2
    soft_def = effective_vit + div(effective_vit, 2)

    hard_def + soft_def
  end
end
