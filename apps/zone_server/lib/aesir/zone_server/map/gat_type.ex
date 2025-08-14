defmodule Aesir.ZoneServer.Map.GatType do
  @moduledoc """
  GAT (Ground Altitude Type) constants and helper functions.
  Based on rAthena's map cell types.
  """

  @gat_walkable 0
  @gat_wall 1
  @gat_walkable_alt 2
  @gat_water 3
  @gat_walkable_alt2 4
  @gat_cliff 5
  @gat_walkable_alt3 6

  def walkable, do: @gat_walkable
  def wall, do: @gat_wall
  def water, do: @gat_water
  def cliff, do: @gat_cliff

  @doc """
  Checks if a GAT type is walkable.
  """
  @spec is_walkable?(integer()) :: boolean()
  def is_walkable?(gat_type) when is_integer(gat_type) do
    gat_type != @gat_wall and gat_type != @gat_cliff
  end

  @doc """
  Checks if a GAT type blocks projectiles.
  Only walls block projectiles.
  """
  @spec blocks_projectile?(integer()) :: boolean()
  def blocks_projectile?(gat_type) when is_integer(gat_type) do
    gat_type == @gat_wall
  end

  @doc """
  Checks if a GAT type is water.
  """
  @spec is_water?(integer()) :: boolean()
  def is_water?(gat_type) when is_integer(gat_type) do
    gat_type == @gat_water
  end

  @doc """
  Checks if a GAT type is a wall.
  """
  @spec is_wall?(integer()) :: boolean()
  def is_wall?(gat_type) when is_integer(gat_type) do
    gat_type == @gat_wall
  end

  @doc """
  Checks if a GAT type is a cliff.
  """
  @spec is_cliff?(integer()) :: boolean()
  def is_cliff?(gat_type) when is_integer(gat_type) do
    gat_type == @gat_cliff
  end

  @doc """
  Returns a description of the GAT type.
  """
  @spec describe(integer()) :: String.t()
  def describe(gat_type) when is_integer(gat_type) do
    case gat_type do
      @gat_walkable -> "walkable"
      @gat_wall -> "wall"
      @gat_walkable_alt -> "walkable (alt)"
      @gat_water -> "water"
      @gat_walkable_alt2 -> "walkable (alt2)"
      @gat_cliff -> "cliff"
      @gat_walkable_alt3 -> "walkable (alt3)"
      _ -> "unknown (#{gat_type})"
    end
  end

  @doc """
  Validates if a GAT type is within the valid range.
  """
  @spec valid?(integer()) :: boolean()
  def valid?(gat_type) when is_integer(gat_type) do
    gat_type >= 0 and gat_type <= 6
  end
end

