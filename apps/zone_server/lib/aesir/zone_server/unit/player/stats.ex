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
            progression: %{base_level: 1, job_level: 1, base_exp: 0, job_exp: 0, job_id: 0},
            current_state: %{hp: 40, sp: 11},
            derived_stats: %{max_hp: 40, max_sp: 11, aspd: 150},
            combat_stats: %{hit: 0, flee: 0, critical: 0, atk: 0, def: 0},
            equipment: %{weapon: 0, shield: 0},
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
            job_exp: integer(),
            job_id: integer()
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
          equipment: %{weapon: integer(), shield: integer()},
          modifiers: %{equipment: map(), status_effects: map(), job_bonuses: map()}
        }

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.JobData
  alias Aesir.ZoneServer.Mmo.WeaponTypes

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
      job_exp: character.job_exp,
      job_id: character.class || 0
    }

    current_state = %{
      hp: character.hp,
      sp: character.sp
    }

    equipment = %{
      weapon: character.weapon || 0,
      shield: character.shield || 0
    }

    stats = %__MODULE__{
      base_stats: base_stats,
      progression: progression,
      current_state: current_state,
      equipment: equipment,
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
    job_bonuses = JobData.get_job_bonuses(stats.progression.job_id, stats.progression.job_level)
    %{stats | modifiers: %{stats.modifiers | job_bonuses: job_bonuses}}
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
    job_id = stats.progression.job_id

    base_hp = JobData.get_base_hp(job_id, base_level)
    base_sp = JobData.get_base_sp(job_id, base_level)

    # Apply VIT/INT modifiers
    max_hp = trunc(base_hp * (1.0 + effective_vit * 0.01))
    max_sp = trunc(base_sp * (1.0 + effective_int * 0.01))

    # Apply job-specific HP factor if any
    hp_factor = JobData.get_hp_factor(job_id)

    max_hp =
      if hp_factor > 0 do
        trunc(max_hp * (100 + hp_factor) / 100)
      else
        max_hp
      end

    # Apply job-specific increases
    hp_increase = JobData.get_hp_increase(job_id)
    sp_increase = JobData.get_sp_increase(job_id)

    max_hp = max_hp + hp_increase + get_hp_bonus_flat(stats)
    max_sp = max_sp + sp_increase + get_sp_bonus_flat(stats)

    max_hp = max(max_hp, 1)
    max_sp = max(max_sp, 1)

    # Calculate ASPD
    aspd = calculate_aspd(stats)

    derived_stats = %{
      max_hp: max_hp,
      max_sp: max_sp,
      aspd: aspd
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

  @doc """
  Calculates ASPD (Attack Speed) following rAthena's renewal formula.

  ASPD in renewal is displayed as: 200 - (delay / 10)
  The actual attack delay in milliseconds is: (200 - ASPD) * 10

  Formula varies based on weapon type:
  - Ranged weapons: sqrt(DEX² / 7 + AGI² * 0.5)
  - Other weapons: sqrt(DEX² / 5 + AGI²)
  """
  @spec calculate_aspd(t()) :: integer()
  def calculate_aspd(%__MODULE__{} = stats) do
    effective_agi = get_effective_stat(stats, :agi)
    effective_dex = get_effective_stat(stats, :dex)
    job_id = stats.progression.job_id
    weapon_type = stats.equipment.weapon
    has_shield = stats.equipment.shield > 0

    # Get base ASPD for job/weapon combination
    base_aspd = JobData.get_base_aspd(job_id, WeaponTypes.get_weapon_atom(weapon_type))

    # Default to barehand if no ASPD data for this weapon
    base_aspd =
      if is_nil(base_aspd) do
        JobData.get_base_aspd(job_id, :barehand) || 156
      else
        base_aspd
      end

    # Apply shield penalty if equipped (rAthena adds shield ASPD value)
    base_aspd =
      if has_shield do
        shield_aspd = JobData.get_base_aspd(job_id, :shield) || 0
        base_aspd - shield_aspd
      else
        base_aspd
      end

    # Calculate stat modifier based on weapon type
    stat_modifier =
      if WeaponTypes.is_ranged?(weapon_type) do
        # Ranged formula: sqrt(DEX² / 7 + AGI² * 0.5)
        :math.sqrt(effective_dex * effective_dex / 7.0 + effective_agi * effective_agi * 0.5)
      else
        # Melee formula: sqrt(DEX² / 5 + AGI²)
        :math.sqrt(effective_dex * effective_dex / 5.0 + effective_agi * effective_agi)
      end

    # Apply stat modifier to base ASPD
    # Formula: base_aspd + sqrt_result * 4 / 10
    final_aspd = base_aspd + trunc(stat_modifier * 4 / 10)

    # Apply ASPD rate modifiers (equipment, buffs, etc.)
    aspd_rate = get_aspd_rate(stats)

    final_aspd =
      if aspd_rate != 100 do
        trunc(final_aspd * aspd_rate / 100)
      else
        final_aspd
      end

    # Cap ASPD between 0 and 193 (renewal limits)
    # 193 is the max ASPD for players in renewal
    min(max(final_aspd, 0), 193)
  end

  # Get ASPD rate modifier from equipment and status effects
  defp get_aspd_rate(%__MODULE__{modifiers: modifiers}) do
    equipment_rate = Map.get(modifiers.equipment, :aspd_rate, 100)
    status_rate = Map.get(modifiers.status_effects, :aspd_rate, 100)

    # Multiplicative stacking
    trunc(equipment_rate * status_rate / 100)
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
