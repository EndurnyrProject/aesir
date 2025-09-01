defmodule Aesir.ZoneServer.Mmo.MobManagement do
  @moduledoc """
  Public API for mob-related operations.
  Provides business logic for mob data access and mob-related calculations.
  """
  require Logger

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDataLoader
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn

  @doc """
  Get a mob by its ID.
  Returns {:ok, mob} or {:error, reason}
  """
  @spec get_mob_by_id(integer()) :: {:ok, MobDefinition.t()} | {:error, atom()}
  def get_mob_by_id(mob_id) when is_integer(mob_id) do
    MobDataLoader.get_mob(mob_id)
  end

  @doc """
  Get a mob by its aegis name.
  Returns {:ok, mob} or {:error, reason}
  """
  @spec get_mob_by_name(atom()) :: {:ok, MobDefinition.t()} | {:error, atom()}
  def get_mob_by_name(aegis_name) when is_atom(aegis_name) do
    MobDataLoader.get_mob(aegis_name)
  end

  @doc """
  Get all available mobs.
  Returns a list of MobDefinition structs.
  """
  @spec get_all_mobs() :: [MobDefinition.t()]
  def get_all_mobs do
    MobDataLoader.get_all_mobs()
  end

  @doc """
  Get spawn data for a specific map.
  Returns {:ok, spawns} or {:error, reason}
  """
  @spec get_spawns_for_map(String.t()) :: {:ok, [MobSpawn.t()]} | {:error, atom()}
  def get_spawns_for_map(map_name) when is_binary(map_name) do
    MobDataLoader.get_spawns_for_map(map_name)
  end

  @doc """
  Get all spawn data.
  Returns a map of map_name => spawn list.
  """
  @spec get_all_spawns() :: %{String.t() => [MobSpawn.t()]}
  def get_all_spawns do
    MobDataLoader.get_all_spawns()
  end

  @doc """
  Calculate actual attack power for a mob.
  Returns the calculated attack value based on min/max range.
  """
  @spec calculate_attack(MobDefinition.t()) :: integer()
  def calculate_attack(%MobDefinition{atk_min: min, atk_max: max}) do
    if min == max do
      min
    else
      # Random value between min and max
      :rand.uniform(max - min + 1) + min - 1
    end
  end

  @doc """
  Calculate hit rate for a mob based on its level and dex.
  """
  @spec calculate_hit_rate(MobDefinition.t()) :: integer()
  def calculate_hit_rate(%MobDefinition{level: level, stats: %{dex: dex}}) do
    # Base formula: level + dex
    level + dex
  end

  @doc """
  Calculate flee rate for a mob based on its level and agi.
  """
  @spec calculate_flee_rate(MobDefinition.t()) :: integer()
  def calculate_flee_rate(%MobDefinition{level: level, stats: %{agi: agi}}) do
    # Base formula: level + agi
    level + agi
  end

  @doc """
  Check if a mob is aggressive based on its AI type.
  """
  @spec aggressive?(MobDefinition.t()) :: boolean()
  def aggressive?(%MobDefinition{ai_type: ai_type}) do
    # AI types that are aggressive (will attack on sight)
    # Type 1 and 3 are typically aggressive in rAthena
    ai_type in [1, 3]
  end

  @doc """
  Check if a mob can move.
  """
  @spec can_move?(MobDefinition.t()) :: boolean()
  def can_move?(%MobDefinition{modes: modes}) do
    :no_move not in modes
  end

  @doc """
  Check if a mob can attack.
  """
  @spec can_attack?(MobDefinition.t()) :: boolean()
  def can_attack?(%MobDefinition{modes: modes}) do
    :no_attack not in modes
  end

  @doc """
  Get element weakness/resistance multiplier.
  Returns a multiplier for damage calculation based on element matchup.
  """
  @spec get_element_modifier(MobDefinition.t(), atom(), integer()) :: float()
  def get_element_modifier(
        %MobDefinition{element: {mob_element, _mob_level}},
        attack_element,
        _attack_level
      ) do
    # This is a simplified version - actual RO element table is more complex
    # Returns 1.0 for neutral, > 1.0 for weakness, < 1.0 for resistance
    case {mob_element, attack_element} do
      # Water vs Fire
      {:water, :fire} -> 0.5
      {:fire, :water} -> 1.5
      # Earth vs Wind
      {:earth, :wind} -> 0.5
      {:wind, :earth} -> 1.5
      # Same element
      {same, same} -> 0.5
      # Default
      _ -> 1.0
    end
  end

  @doc """
  Calculate experience penalty/bonus based on level difference.
  """
  @spec calculate_exp_modifier(integer(), integer()) :: float()
  def calculate_exp_modifier(mob_level, player_level) do
    level_diff = abs(mob_level - player_level)

    cond do
      level_diff <= 5 -> 1.0
      level_diff <= 10 -> 0.9
      level_diff <= 15 -> 0.8
      level_diff <= 20 -> 0.7
      true -> 0.6
    end
  end

  @doc """
  Get drop rate with server rates applied.
  """
  @spec calculate_drop_rate(integer(), float()) :: integer()
  def calculate_drop_rate(base_rate, server_rate_multiplier \\ 1.0) do
    round(base_rate * server_rate_multiplier)
  end

  @doc """
  Get a random spawn position within spawn area constraints.
  """
  @spec get_random_spawn_position(
          MobSpawn.SpawnArea.t(),
          map_dimensions :: {integer(), integer()}
        ) ::
          {:ok, {integer(), integer()}} | {:error, :invalid_spawn_area}
  def get_random_spawn_position(
        %MobSpawn.SpawnArea{x: x, y: y, xs: xs, ys: ys},
        {map_width, map_height}
      ) do
    if x == 0 and y == 0 and xs == 0 and ys == 0 do
      # Entire map spawn
      spawn_x = :rand.uniform(map_width - 1)
      spawn_y = :rand.uniform(map_height - 1)
      {:ok, {spawn_x, spawn_y}}
    else
      # Specific area spawn
      min_x = max(0, x - xs)
      max_x = min(map_width - 1, x + xs)
      min_y = max(0, y - ys)
      max_y = min(map_height - 1, y + ys)

      if min_x <= max_x and min_y <= max_y do
        spawn_x = :rand.uniform(max_x - min_x + 1) + min_x - 1
        spawn_y = :rand.uniform(max_y - min_y + 1) + min_y - 1
        {:ok, {spawn_x, spawn_y}}
      else
        {:error, :invalid_spawn_area}
      end
    end
  end
end
