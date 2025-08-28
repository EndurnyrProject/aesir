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
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.WeaponTypes

  @doc """
  Creates a Stats struct from a Character model.
  """
  @spec from_character(map()) :: t()
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

  ## Parameters
  - stats: The Stats struct to calculate
  - player_id: Optional player ID for status effect retrieval
  """
  @spec calculate_stats(t(), integer() | nil) :: t()
  def calculate_stats(%__MODULE__{} = stats, player_id \\ nil) do
    stats
    |> apply_job_bonuses()
    |> apply_equipment_modifiers()
    |> apply_status_effects(player_id)
    |> calculate_derived_stats()
    |> calculate_combat_stats()
  end

  @doc """
  Applies job-specific stat bonuses based on job level and class.
  """
  @spec apply_job_bonuses(t()) :: t()
  def apply_job_bonuses(%__MODULE__{} = stats) do
    job_bonuses =
      with {:ok, job_name} <- AvailableJobs.job_id_to_name(stats.progression.job_id),
           {:ok, bonus_stats} <-
             JobManagement.get_bonus_stats(
               job_name,
               stats.progression.job_level
             ) do
        %{
          str: bonus_stats.str || 0,
          agi: bonus_stats.agi || 0,
          vit: bonus_stats.vit || 0,
          int: bonus_stats.int || 0,
          dex: bonus_stats.dex || 0,
          luk: bonus_stats.luk || 0
        }
      else
        {:error, :level_out_of_range} ->
          # No bonuses for this level (common for level 1)
          %{}

        err ->
          raise "Failed to get job bonuses: #{inspect(err)}"
      end

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
  Fetches active status effects for the player and applies their stat modifiers.

  ## Parameters
  - stats: The Stats struct to update
  - player_id: The player ID to get status effects for

  ## Returns
  Updated Stats struct with status effect modifiers applied
  """
  @spec apply_status_effects(t(), integer() | nil) :: t()
  def apply_status_effects(%__MODULE__{} = stats, player_id) when is_integer(player_id) do
    # Get all status effect modifiers for this player
    status_modifiers = Interpreter.get_all_modifiers(player_id)

    # Update the status_effects in modifiers
    %{stats | modifiers: %{stats.modifiers | status_effects: status_modifiers}}
  end

  # When player_id is nil or invalid
  @spec apply_status_effects(t(), any()) :: t()
  def apply_status_effects(%__MODULE__{} = stats, _player_id) do
    # Without a valid player_id, we can't get status effects, so return unchanged
    stats
  end

  # Backwards compatibility for the original function signature
  @spec apply_status_effects(t()) :: t()
  def apply_status_effects(%__MODULE__{} = stats) do
    # Without a player_id, we can't get status effects, so return unchanged
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

    with {:ok, job_name} <- AvailableJobs.job_id_to_name(stats.progression.job_id) do
      # Get all job-related stats
      job_stats = get_job_stats_for_level(job_name, base_level)

      # Calculate HP/SP with modifiers
      max_hp =
        calculate_max_hp(
          job_stats.base_hp,
          effective_vit,
          job_stats.hp_factor,
          job_stats.hp_increase,
          stats
        )

      max_sp = calculate_max_sp(job_stats.base_sp, effective_int, job_stats.sp_increase, stats)

      # Calculate ASPD
      aspd = calculate_aspd(stats)

      derived_stats = %{
        max_hp: max_hp,
        max_sp: max_sp,
        aspd: aspd
      }

      %{stats | derived_stats: derived_stats}
    else
      err -> raise "Failed to get job name for derived stats: #{inspect(err)}"
    end
  end

  @doc """
  Calculates combat-related stats (hit, flee, critical, atk, def).
  Includes status effect modifiers from the modifiers map.
  """
  @spec calculate_combat_stats(t()) :: t()
  def calculate_combat_stats(%__MODULE__{} = stats) do
    base_hit = calculate_base_hit(stats)
    base_flee = calculate_base_flee(stats)
    base_critical = calculate_base_critical(stats)
    base_atk = calculate_base_atk(stats)
    base_def = calculate_base_def(stats)

    hit = base_hit + get_status_modifier(stats, :hit)
    flee = base_flee + get_status_modifier(stats, :flee)
    critical = base_critical + get_status_modifier(stats, :critical)
    atk = base_atk + get_status_modifier(stats, :atk)
    def = base_def + get_status_modifier(stats, :def)

    combat_stats = %{
      hit: hit,
      flee: flee,
      critical: critical,
      atk: atk,
      def: def
    }

    %{stats | combat_stats: combat_stats}
  end

  defp calculate_base_hit(%__MODULE__{} = stats) do
    effective_dex = get_effective_stat(stats, :dex)
    effective_luk = get_effective_stat(stats, :luk)

    # Basic formula: hit = DEX + LUK/3 + base level / 4
    base_level = stats.progression.base_level
    trunc(effective_dex + effective_luk / 3 + base_level / 4)
  end

  defp calculate_base_flee(%__MODULE__{} = stats) do
    effective_agi = get_effective_stat(stats, :agi)
    effective_luk = get_effective_stat(stats, :luk)

    # Basic formula: flee = AGI + LUK/5 + base level / 4
    base_level = stats.progression.base_level
    trunc(effective_agi + effective_luk / 5 + base_level / 4)
  end

  defp calculate_base_critical(%__MODULE__{} = stats) do
    effective_luk = get_effective_stat(stats, :luk)

    # Basic formula: critical = LUK / 3
    trunc(effective_luk / 3)
  end

  defp calculate_base_atk(%__MODULE__{} = stats) do
    effective_str = get_effective_stat(stats, :str)

    # Basic formula: atk = STR + base level / 4
    base_level = stats.progression.base_level
    trunc(effective_str + base_level / 4)
  end

  defp calculate_base_def(%__MODULE__{} = stats) do
    effective_vit = get_effective_stat(stats, :vit)

    # Basic formula: def = VIT/2 + base level / 6
    base_level = stats.progression.base_level
    trunc(effective_vit / 2 + base_level / 6)
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
  Gets all status effect modifiers for a specific stat or property.
  This is useful for applying specific types of modifiers from status effects.

  ## Parameters
  - stats: The Stats struct
  - modifier_key: The modifier to look up (e.g., :hit, :flee, :aspd_rate)

  ## Returns
  The combined value of all modifiers for the given key, or 0 if none exist
  """
  @spec get_status_modifier(t(), atom()) :: number()
  def get_status_modifier(%__MODULE__{} = stats, modifier_key) do
    Map.get(stats.modifiers.status_effects, modifier_key, 0)
  end

  @doc """
  Checks if the player has a specific status flag set by status effects.
  This is used for boolean properties like 'endure' or 'hiding'.

  ## Parameters
  - stats: The Stats struct
  - flag: The flag to check for (e.g., :endure, :hiding)

  ## Returns
  Boolean indicating whether the flag is set
  """
  @spec has_status_flag?(t(), atom()) :: boolean()
  def has_status_flag?(%__MODULE__{} = stats, flag) do
    Map.get(stats.modifiers.status_effects, flag, false)
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
    weapon_type = stats.equipment.weapon
    has_shield = stats.equipment.shield > 0

    with {:ok, job_name} <- AvailableJobs.job_id_to_name(stats.progression.job_id) do
      base_aspd = get_weapon_aspd(job_name, weapon_type)

      base_aspd =
        if has_shield do
          apply_shield_penalty(base_aspd, job_name)
        else
          base_aspd
        end

      # Convert base ASPD to amotion (attack motion delay in milliseconds)
      # Stores base values as amotion/10, so base_aspd of 40 = 400ms amotion
      base_amotion = base_aspd * 10

      # amotion = base_amotion - (base_amotion * (4 * agi + dex) / 1000)
      stat_reduction = div(base_amotion * (4 * effective_agi + effective_dex), 1000)
      amotion = base_amotion - stat_reduction

      # Convert amotion back to ASPD display value
      # ASPD = (2000 - amotion) / 10
      final_aspd = div(2000 - amotion, 10)

      # Apply ASPD rate modifiers
      final_aspd = apply_aspd_rate_modifiers(final_aspd, stats)

      # Cap ASPD between 0 and 193
      min(max(final_aspd, 0), 193)
    else
      err -> raise "Failed to get job name for ASPD calculation: #{inspect(err)}"
    end
  end

  defp get_job_stats_for_level(job_name, base_level) do
    with {:ok, base_stats} <- JobManagement.get_base_stats_for_level(job_name, base_level),
         {:ok, job} <- JobManagement.get_job_by_name(job_name) do
      %{
        base_hp: base_stats.hp,
        base_sp: base_stats.sp,
        hp_factor: job.hp_factor || 0,
        hp_increase: job.hp_increase || 0,
        sp_increase: job.sp_increase || 0
      }
    else
      _ ->
        raise "Failed to get job stats for level #{base_level} of job #{job_name}"
    end
  end

  defp calculate_max_hp(base_hp, effective_vit, hp_factor, hp_increase, stats) do
    # Apply VIT modifier
    hp_with_vit = trunc(base_hp * (1.0 + effective_vit * 0.01))

    # Apply job-specific HP factor if any
    hp_with_factor =
      if hp_factor && hp_factor > 0 do
        trunc(hp_with_vit * (100 + hp_factor) / 100)
      else
        hp_with_vit
      end

    # Apply increases and bonuses
    hp_increase_value = hp_increase || 0
    total_hp = hp_with_factor + hp_increase_value + get_hp_bonus_flat(stats)

    max(total_hp, 1)
  end

  defp calculate_max_sp(base_sp, effective_int, sp_increase, stats) do
    # Apply INT modifier
    sp_with_int = trunc(base_sp * (1.0 + effective_int * 0.01))

    # Apply increases and bonuses
    sp_increase_value = sp_increase || 0
    total_sp = sp_with_int + sp_increase_value + get_sp_bonus_flat(stats)

    max(total_sp, 1)
  end

  defp get_weapon_aspd(job_name, weapon_type) do
    weapon_atom = WeaponTypes.get_weapon_atom(weapon_type)

    with {:ok, aspd} <- JobManagement.get_base_aspd(job_name, weapon_atom) do
      aspd
    else
      _ ->
        raise "Failed to get base ASPD for job #{job_name} and weapon type #{inspect(weapon_atom)}"
    end
  end

  defp apply_shield_penalty(base_aspd, job_name) do
    with {:ok, shield_penalty} <- JobManagement.get_base_aspd(job_name, :shield) do
      base_aspd + shield_penalty
    else
      _ -> base_aspd
    end
  end

  @spec apply_aspd_rate_modifiers(integer(), t()) :: integer()
  defp apply_aspd_rate_modifiers(aspd, stats) do
    aspd_rate = get_aspd_rate(stats)

    if aspd_rate != 100 do
      trunc(aspd * aspd_rate / 100)
    else
      aspd
    end
  end

  defp get_aspd_rate(%__MODULE__{modifiers: modifiers}) do
    equipment_rate = Map.get(modifiers.equipment, :aspd_rate, 100)
    status_rate = Map.get(modifiers.status_effects, :aspd_rate, 100)

    # Multiplicative stacking
    trunc(equipment_rate * status_rate / 100)
  end

  defp get_hp_bonus_flat(%__MODULE__{}) do
    # TODO: Implement equipment and status effect HP bonuses
    0
  end

  defp get_sp_bonus_flat(%__MODULE__{}) do
    # TODO: Implement equipment and status effect SP bonuses
    0
  end
end
