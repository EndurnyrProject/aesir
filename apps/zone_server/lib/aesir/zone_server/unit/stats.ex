defmodule Aesir.ZoneServer.Unit.Stats do
  @moduledoc """
  Common stats structure for all unit types in the game.

  This module defines the base stats that are shared across all entities
  (players, monsters, NPCs, etc.). It provides the foundation for
  stat calculations, including base attributes, derived values, and
  current state.
  """

  use TypedStruct

  defmodule BaseStats do
    @moduledoc false

    use TypedStruct

    @typedoc "Core attributes for all units"
    typedstruct do
      field :str, non_neg_integer()
      field :agi, non_neg_integer()
      field :vit, non_neg_integer()
      field :int, non_neg_integer()
      field :dex, non_neg_integer()
      field :luk, non_neg_integer()
      field :pow, non_neg_integer(), default: 0
      field :sta, non_neg_integer(), default: 0
      field :wis, non_neg_integer(), default: 0
      field :spl, non_neg_integer(), default: 0
      field :con, non_neg_integer(), default: 0
      field :crt, non_neg_integer(), default: 0
    end
  end

  defmodule DerivedStats do
    @moduledoc false

    use TypedStruct

    @typedoc "Calculated values derived from base stats"
    typedstruct do
      field :max_hp, non_neg_integer()
      field :max_sp, non_neg_integer()
      field :aspd, integer()
      field :max_ap, non_neg_integer(), default: 0
    end
  end

  defmodule CombatStats do
    @moduledoc false

    use TypedStruct

    alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack

    @typedoc """
    Battle-related statistics.

    `atk_min`/`atk_max` bound the weapon roll of a unit without a weapon hand
    (monsters and homunculi); players leave them nil.
    """
    typedstruct do
      field :atk, non_neg_integer()
      field :atk_min, non_neg_integer()
      field :atk_max, non_neg_integer()
      field :physical_attack, PhysicalAttack.snapshot()
      field :matk, non_neg_integer()
      field :matk_min, non_neg_integer()
      field :matk_max, non_neg_integer()
      field :heal_matk_min, non_neg_integer()
      field :heal_matk_max, non_neg_integer()
      field :def, non_neg_integer()
      field :soft_def, non_neg_integer()
      field :mdef, non_neg_integer()
      field :soft_mdef, non_neg_integer()
      field :hit, non_neg_integer()
      field :flee, non_neg_integer()
      field :critical, non_neg_integer()
      field :critical_rate, integer()
      field :perfect_dodge, non_neg_integer()
      field :passive_atk, non_neg_integer()
      field :hit_rate_bonus_pct, non_neg_integer(), default: 0
      field :patk, non_neg_integer(), default: 0
      field :smatk, non_neg_integer(), default: 0
      field :res, non_neg_integer(), default: 0
      field :mres, non_neg_integer(), default: 0
      field :hplus, non_neg_integer(), default: 0
      field :crate, non_neg_integer(), default: 0
      field :overrefine_band, non_neg_integer(), default: 0
      field :ignore_size_penalty, boolean(), default: false
      field :max_weapon_damage, boolean(), default: false
    end
  end

  defmodule CurrentState do
    @moduledoc false

    use TypedStruct

    @typedoc "Current HP/SP values"
    typedstruct do
      field :hp, non_neg_integer()
      field :sp, non_neg_integer()
      field :ap, non_neg_integer(), default: 0
    end
  end

  defmodule Progression do
    @moduledoc false

    use TypedStruct

    @typedoc "Level information"
    typedstruct do
      field :base_level, non_neg_integer()
      field :job_level, non_neg_integer()
    end
  end

  @typedoc """
  Common stats structure for all units.

  ## Fields
  - `base_stats`: Core attributes (STR, AGI, VIT, INT, DEX, LUK)
  - `derived_stats`: Calculated values (max HP/SP, ASPD, etc.)
  - `combat_stats`: Battle-related stats (ATK, DEF, MDEF, HIT, FLEE, etc.)
  - `current_state`: Current HP/SP values
  - `progression`: Level information
  """
  typedstruct do
    field :base_stats, BaseStats.t()
    field :derived_stats, DerivedStats.t()
    field :combat_stats, CombatStats.t()
    field :current_state, CurrentState.t()
    field :progression, Progression.t()
  end

  @doc """
  Creates a new stats structure with default values.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new stats structure with the given attributes.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Extracts stats in the format expected by status effect formulas.
  Returns a flat map with all stats for easy access in calculations.
  """
  @spec to_formula_map(t()) :: map()
  def to_formula_map(%__MODULE__{} = stats) do
    %{
      # Base stats
      str: stats.base_stats.str,
      agi: stats.base_stats.agi,
      vit: stats.base_stats.vit,
      int: stats.base_stats.int,
      dex: stats.base_stats.dex,
      luk: stats.base_stats.luk,
      # No separate modifier layer here, so the calculated stats are the base ones.
      total_stats: primary_stats(stats),
      unbuffed_stats: primary_stats(stats),
      # HP/SP
      max_hp: stats.derived_stats.max_hp,
      max_sp: stats.derived_stats.max_sp,
      hp: stats.current_state.hp,
      sp: stats.current_state.sp,
      # Level
      level: stats.progression.base_level,
      base_level: stats.progression.base_level,
      job_level: stats.progression.job_level,
      # Combat stats
      atk: stats.combat_stats.atk,
      matk: stats.combat_stats.matk,
      def: stats.combat_stats.def,
      mdef: stats.combat_stats.mdef,
      hit: stats.combat_stats.hit,
      flee: stats.combat_stats.flee,
      critical: stats.combat_stats.critical,
      aspd: stats.derived_stats.aspd
    }
  end

  @spec primary_stats(t()) :: %{atom() => integer()}
  defp primary_stats(%__MODULE__{base_stats: base}) do
    %{str: base.str, agi: base.agi, vit: base.vit, int: base.int, dex: base.dex, luk: base.luk}
  end

  @doc """
  Updates current HP/SP state.
  """
  @spec update_current_state(t(), CurrentState.t() | map()) :: t()
  def update_current_state(%__MODULE__{} = stats, %CurrentState{} = new_state) do
    %{stats | current_state: new_state}
  end

  def update_current_state(%__MODULE__{} = stats, updates) when is_map(updates) do
    %{stats | current_state: struct(stats.current_state, updates)}
  end

  @doc """
  Checks if the unit is dead (HP is 0).
  """
  @spec dead?(t()) :: boolean()
  def dead?(%__MODULE__{current_state: %CurrentState{hp: 0}}), do: true
  def dead?(%__MODULE__{}), do: false
end
