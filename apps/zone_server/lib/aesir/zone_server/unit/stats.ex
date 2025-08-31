defmodule Aesir.ZoneServer.Unit.Stats do
  @moduledoc """
  Common stats structure for all unit types in the game.

  This module defines the base stats that are shared across all entities
  (players, monsters, NPCs, etc.). It provides the foundation for
  stat calculations, including base attributes, derived values, and
  current state.
  """

  use TypedStruct

  typedstruct module: BaseStats do
    @typedoc "Core attributes for all units"
    field :str, non_neg_integer()
    field :agi, non_neg_integer()
    field :vit, non_neg_integer()
    field :int, non_neg_integer()
    field :dex, non_neg_integer()
    field :luk, non_neg_integer()
  end

  typedstruct module: DerivedStats do
    @typedoc "Calculated values derived from base stats"
    field :max_hp, non_neg_integer()
    field :max_sp, non_neg_integer()
    field :aspd, non_neg_integer()
  end

  typedstruct module: CombatStats do
    @typedoc "Battle-related statistics"
    field :atk, non_neg_integer()
    field :matk, non_neg_integer()
    field :def, non_neg_integer()
    field :mdef, non_neg_integer()
    field :hit, non_neg_integer()
    field :flee, non_neg_integer()
    field :critical, non_neg_integer()
    field :perfect_dodge, non_neg_integer()
  end

  typedstruct module: CurrentState do
    @typedoc "Current HP/SP values"
    field :hp, non_neg_integer()
    field :sp, non_neg_integer()
  end

  typedstruct module: Progression do
    @typedoc "Level information"
    field :base_level, non_neg_integer()
    field :job_level, non_neg_integer()
  end

  typedstruct do
    @typedoc """
    Common stats structure for all units.

    ## Fields
    - `base_stats`: Core attributes (STR, AGI, VIT, INT, DEX, LUK)
    - `derived_stats`: Calculated values (max HP/SP, ASPD, etc.)
    - `combat_stats`: Battle-related stats (ATK, DEF, MDEF, HIT, FLEE, etc.)
    - `current_state`: Current HP/SP values
    - `progression`: Level information
    """

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

  @doc """
  Updates base stats.
  """
  @spec update_base_stats(t(), BaseStats.t() | map()) :: t()
  def update_base_stats(%__MODULE__{} = stats, %BaseStats{} = new_base_stats) do
    %{stats | base_stats: new_base_stats}
  end

  def update_base_stats(%__MODULE__{} = stats, updates) when is_map(updates) do
    %{stats | base_stats: struct(stats.base_stats, updates)}
  end

  @doc """
  Updates derived stats.
  """
  @spec update_derived_stats(t(), DerivedStats.t() | map()) :: t()
  def update_derived_stats(%__MODULE__{} = stats, %DerivedStats{} = new_derived_stats) do
    %{stats | derived_stats: new_derived_stats}
  end

  def update_derived_stats(%__MODULE__{} = stats, updates) when is_map(updates) do
    %{stats | derived_stats: struct(stats.derived_stats, updates)}
  end

  @doc """
  Updates combat stats.
  """
  @spec update_combat_stats(t(), CombatStats.t() | map()) :: t()
  def update_combat_stats(%__MODULE__{} = stats, %CombatStats{} = new_combat_stats) do
    %{stats | combat_stats: new_combat_stats}
  end

  def update_combat_stats(%__MODULE__{} = stats, updates) when is_map(updates) do
    %{stats | combat_stats: struct(stats.combat_stats, updates)}
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
  Applies damage to HP.
  """
  @spec apply_damage(t(), integer()) :: t()
  def apply_damage(%__MODULE__{} = stats, damage) when is_integer(damage) do
    new_hp = max(0, stats.current_state.hp - damage)
    update_current_state(stats, %{hp: new_hp})
  end

  @doc """
  Applies healing to HP.
  """
  @spec apply_healing(t(), integer()) :: t()
  def apply_healing(%__MODULE__{} = stats, amount) when is_integer(amount) do
    new_hp = min(stats.derived_stats.max_hp, stats.current_state.hp + amount)
    update_current_state(stats, %{hp: new_hp})
  end

  @doc """
  Consumes SP.
  """
  @spec consume_sp(t(), integer()) :: {:ok, t()} | {:error, :insufficient_sp}
  def consume_sp(%__MODULE__{} = stats, amount) when is_integer(amount) do
    if stats.current_state.sp >= amount do
      new_sp = stats.current_state.sp - amount
      {:ok, update_current_state(stats, %{sp: new_sp})}
    else
      {:error, :insufficient_sp}
    end
  end

  @doc """
  Restores SP.
  """
  @spec restore_sp(t(), integer()) :: t()
  def restore_sp(%__MODULE__{} = stats, amount) when is_integer(amount) do
    new_sp = min(stats.derived_stats.max_sp, stats.current_state.sp + amount)
    update_current_state(stats, %{sp: new_sp})
  end

  @doc """
  Checks if the unit is dead (HP is 0).
  """
  @spec dead?(t()) :: boolean()
  def dead?(%__MODULE__{current_state: %CurrentState{hp: 0}}), do: true
  def dead?(%__MODULE__{}), do: false

  @doc """
  Gets the HP percentage.
  """
  @spec hp_percentage(t()) :: float()
  def hp_percentage(%__MODULE__{} = stats) do
    if stats.derived_stats.max_hp > 0 do
      stats.current_state.hp / stats.derived_stats.max_hp * 100.0
    else
      0.0
    end
  end

  @doc """
  Gets the SP percentage.
  """
  @spec sp_percentage(t()) :: float()
  def sp_percentage(%__MODULE__{} = stats) do
    if stats.derived_stats.max_sp > 0 do
      stats.current_state.sp / stats.derived_stats.max_sp * 100.0
    else
      0.0
    end
  end
end
