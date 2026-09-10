defmodule Aesir.ZoneServer.Mmo.MobManagement do
  @moduledoc """
  Public API for mob-related operations.
  Provides business logic for mob data access and mob-related calculations.
  """
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns

  @doc """
  Get a mob by its ID.
  Returns {:ok, mob} or {:error, reason}
  """
  @spec get_mob_by_id(integer()) :: {:ok, MobDefinition.t()} | {:error, :mob_not_found}
  def get_mob_by_id(mob_id) when is_integer(mob_id) do
    with :error <- Mobs.by_id(mob_id), do: {:error, :mob_not_found}
  end

  @doc """
  Get a mob by its aegis name.
  Returns {:ok, mob} or {:error, reason}
  """
  @spec get_mob_by_name(String.t()) :: {:ok, MobDefinition.t()} | {:error, :mob_not_found}
  def get_mob_by_name(aegis_name) when is_binary(aegis_name) do
    with :error <- Mobs.by_name(aegis_name), do: {:error, :mob_not_found}
  end

  @doc """
  Get all available mobs.
  Returns a list of MobDefinition structs.
  """
  @spec get_all_mobs() :: [MobDefinition.t()]
  def get_all_mobs do
    Mobs.all()
  end

  @doc """
  Get spawn data for a specific map.
  Returns {:ok, spawns} or {:error, reason}
  """
  @spec get_spawns_for_map(String.t()) :: {:ok, [MobSpawn.t()]} | {:error, :no_spawns}
  def get_spawns_for_map(map_name) when is_binary(map_name) do
    with :error <- Spawns.for_map(map_name), do: {:error, :no_spawns}
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
end
