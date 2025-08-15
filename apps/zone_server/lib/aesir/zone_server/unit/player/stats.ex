defmodule Aesir.ZoneServer.Unit.Player.Stats do
  @moduledoc """
  Player statistics management for individual character sessions.

  Manages character base stats, derived stats, and modifiers with a three-tier architecture:
  - Database Layer: Persistent base stats from Character model
  - Calculation Layer: Runtime stat calculations with modifiers
  - Display Layer: Client synchronization via StatusParams

  This module is designed to work closely with PlayerSession and PlayerState for
  real-time stat calculations and client synchronization.
  """

  defstruct base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
            progression: %{base_level: 1, job_level: 1, base_exp: 0, job_exp: 0},
            current_state: %{hp: 40, sp: 11},
            derived_stats: %{max_hp: 40, max_sp: 11, aspd: 0},
            combat_stats: %{hit: 0, flee: 0, critical: 0, atk: 0, def: 0},
            modifiers: %{
              equipment: %{},
              status_effects: %{},
              job_bonuses: %{}
            }

  @type t :: %__MODULE__{
          base_stats: %{
            str: integer(),
            agi: integer(),
            vit: integer(),
            int: integer(),
            dex: integer(),
            luk: integer()
          },
          progression: %{
            base_level: integer(),
            job_level: integer(),
            base_exp: integer(),
            job_exp: integer()
          },
          current_state: %{hp: integer(), sp: integer()},
          derived_stats: %{max_hp: integer(), max_sp: integer(), aspd: integer()},
          combat_stats: %{
            hit: integer(),
            flee: integer(),
            critical: integer(),
            atk: integer(),
            def: integer()
          },
          modifiers: %{equipment: map(), status_effects: map(), job_bonuses: map()}
        }

  alias Aesir.Commons.Models.Character

  @doc """
  Creates a Stats struct from a Character model.
  """
  @spec from_character(Character.t()) :: t()
  def from_character(%Character{} = character) do
    base_stats = %{
      str: character.str,
      agi: character.agi,
      vit: character.vit,
      int: character.int,
      dex: character.dex,
      luk: character.luk
    }

    progression = %{
      base_level: character.base_level,
      job_level: character.job_level,
      base_exp: character.base_exp,
      job_exp: character.job_exp
    }

    current_state = %{
      hp: character.hp,
      sp: character.sp
    }

    stats = %__MODULE__{
      base_stats: base_stats,
      progression: progression,
      current_state: current_state,
      modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
    }

    calculate_stats(stats)
  end

  @doc """
  Calculates all stats from base values and modifiers.
  This is the main calculation pipeline following rAthena patterns.
  """
  @spec calculate_stats(t()) :: t()
  def calculate_stats(%__MODULE__{} = stats) do
    stats
    |> apply_job_bonuses()
    |> apply_equipment_modifiers()
    |> apply_status_effects()
    |> calculate_derived_stats()
    |> calculate_combat_stats()
  end

  @doc """
  Applies job-specific stat bonuses based on job level and class.
  Currently returns stats unchanged - job bonuses will be implemented with job system.
  """
  @spec apply_job_bonuses(t()) :: t()
  def apply_job_bonuses(%__MODULE__{} = stats) do
    # TODO: Implement job bonus system
    # job_bonuses = get_job_bonuses(stats.progression.job_id, stats.progression.job_level)
    # %{stats | modifiers: %{stats.modifiers | job_bonuses: job_bonuses}}
    stats
  end

  @doc """
  Applies equipment modifiers to stats.
  Currently returns stats unchanged - equipment modifiers will be implemented with equipment system.
  """
  @spec apply_equipment_modifiers(t()) :: t()
  def apply_equipment_modifiers(%__MODULE__{} = stats) do
    # TODO: Implement equipment modifier system
    # equipment_bonuses = get_equipment_bonuses(equipment_list)
    # %{stats | modifiers: %{stats.modifiers | equipment: equipment_bonuses}}
    stats
  end

  @doc """
  Applies temporary status effect modifiers.
  Currently returns stats unchanged - status effects will be implemented with status system.
  """
  @spec apply_status_effects(t()) :: t()
  def apply_status_effects(%__MODULE__{} = stats) do
    # TODO: Implement status effect system
    # status_bonuses = get_status_effect_bonuses(status_effects)
    # %{stats | modifiers: %{stats.modifiers | status_effects: status_bonuses}}
    stats
  end

  @doc """
  Calculates derived stats (HP, SP) using rAthena Post-Renewal formulas.

  HP Formula: base_hp[level] * (1.0 + vit * 0.01) + bonuses
  SP Formula: base_sp[level] * (1.0 + int * 0.01) + bonuses
  """
  @spec calculate_derived_stats(t()) :: t()
  def calculate_derived_stats(%__MODULE__{} = stats) do
    effective_vit = get_effective_stat(stats, :vit)
    effective_int = get_effective_stat(stats, :int)
    base_level = stats.progression.base_level

    base_hp = get_base_hp_for_level(base_level)
    max_hp = trunc(base_hp * (1.0 + effective_vit * 0.01))

    base_sp = get_base_sp_for_level(base_level)
    max_sp = trunc(base_sp * (1.0 + effective_int * 0.01))

    max_hp = max_hp + get_hp_bonus_flat(stats)
    max_sp = max_sp + get_sp_bonus_flat(stats)

    max_hp = max(max_hp, 1)
    max_sp = max(max_sp, 1)

    derived_stats = %{
      max_hp: max_hp,
      max_sp: max_sp,
      # TODO: Implement ASPD calculation
      aspd: 0
    }

    %{stats | derived_stats: derived_stats}
  end

  @doc """
  Calculates combat-related stats (hit, flee, critical, atk, def).
  Placeholder implementation - will be expanded with combat system.
  """
  @spec calculate_combat_stats(t()) :: t()
  def calculate_combat_stats(%__MODULE__{} = stats) do
    # TODO: Implement proper combat stat calculations
    combat_stats = %{
      hit: 0,
      flee: 0,
      critical: 0,
      atk: 0,
      def: 0
    }

    %{stats | combat_stats: combat_stats}
  end

  @doc """
  Gets the effective value of a stat including all modifiers.
  """
  @spec get_effective_stat(t(), atom()) :: integer()
  def get_effective_stat(%__MODULE__{} = stats, stat_name)
      when stat_name in [:str, :agi, :vit, :int, :dex, :luk] do
    base_value = Map.get(stats.base_stats, stat_name, 0)

    job_bonus = get_in(stats.modifiers, [:job_bonuses, stat_name]) || 0
    equipment_bonus = get_in(stats.modifiers, [:equipment, stat_name]) || 0
    status_bonus = get_in(stats.modifiers, [:status_effects, stat_name]) || 0

    base_value + job_bonus + equipment_bonus + status_bonus
  end

  # Base HP values per level for Novice/1st job class (simplified)
  # TODO: Replace with proper job-based HP tables
  defp get_base_hp_for_level(level) when level >= 1 and level <= 99 do
    # Simplified linear progression: 35 + level * 5
    35 + level * 5
  end

  defp get_base_hp_for_level(level) when level >= 100 do
    535 + (level - 99) * 10
  end

  # Base SP values per level for Novice/1st job class (simplified) 
  # TODO: Replace with proper job-based SP tables
  defp get_base_sp_for_level(level) when level >= 1 and level <= 99 do
    10 + level * 2
  end

  defp get_base_sp_for_level(level) when level >= 100 do
    208 + (level - 99) * 3
  end

  # HP bonus from equipment/status effects (flat)
  defp get_hp_bonus_flat(%__MODULE__{}) do
    # TODO: Implement equipment and status effect HP bonuses
    0
  end

  # SP bonus from equipment/status effects (flat)
  defp get_sp_bonus_flat(%__MODULE__{}) do
    # TODO: Implement equipment and status effect SP bonuses
    0
  end
end
