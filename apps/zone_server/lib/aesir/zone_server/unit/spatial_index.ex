defmodule Aesir.ZoneServer.Unit.SpatialIndex do
  @moduledoc """
  ETS-based spatial indexing for O(1) player lookups.
  Uses grid cells for efficient range queries.
  """

  # 8x8 map cells per grid cell
  @cell_size 8

  @doc """
  Initializes the ETS tables for spatial indexing.
  Call this from application startup.
  """
  def init do
    # Table for player positions: {char_id, {map_name, x, y}}
    if :ets.info(:player_positions) == :undefined do
      :ets.new(:player_positions, [:set, :public, :named_table])
    end

    # Spatial index by grid cell: {{map_name, cell_x, cell_y}, MapSet.t(char_id)}
    if :ets.info(:spatial_index) == :undefined do
      :ets.new(:spatial_index, [:set, :public, :named_table])
    end

    :ok
  end

  @doc """
  Adds a player to the spatial index.
  """
  def add_player(char_id, x, y, map_name) do
    :ets.insert(:player_positions, {char_id, {map_name, x, y}})

    cell_key = cell_key(map_name, x, y)

    players =
      case :ets.lookup(:spatial_index, cell_key) do
        [{^cell_key, existing}] -> existing
        [] -> MapSet.new()
      end

    updated = MapSet.put(players, char_id)

    :ets.insert(:spatial_index, {cell_key, updated})

    :ok
  end

  @doc """
  Updates a player's position in the index.
  """
  def update_position(char_id, new_x, new_y, new_map) do
    case :ets.lookup(:player_positions, char_id) do
      [{^char_id, {old_map, old_x, old_y}}] ->
        old_cell = cell_key(old_map, old_x, old_y)

        case :ets.lookup(:spatial_index, old_cell) do
          [{^old_cell, players}] ->
            updated = MapSet.delete(players, char_id)

            if MapSet.size(updated) == 0 do
              :ets.delete(:spatial_index, old_cell)
            else
              :ets.insert(:spatial_index, {old_cell, updated})
            end

          _ ->
            :ok
        end

        new_cell = cell_key(new_map, new_x, new_y)

        players =
          case :ets.lookup(:spatial_index, new_cell) do
            [{^new_cell, existing}] -> existing
            [] -> MapSet.new()
          end

        updated = MapSet.put(players, char_id)

        :ets.insert(:spatial_index, {new_cell, updated})
        :ets.insert(:player_positions, {char_id, {new_map, new_x, new_y}})

        :ok

      _ ->
        add_player(char_id, new_x, new_y, new_map)
    end
  end

  @doc """
  Removes a player from the spatial index.
  """
  def remove_player(char_id) do
    case :ets.lookup(:player_positions, char_id) do
      [{^char_id, {map_name, x, y}}] ->
        cell = cell_key(map_name, x, y)

        case :ets.lookup(:spatial_index, cell) do
          [{^cell, players}] ->
            updated = MapSet.delete(players, char_id)

            if MapSet.size(updated) == 0 do
              :ets.delete(:spatial_index, cell)
            else
              :ets.insert(:spatial_index, {cell, updated})
            end

          _ ->
            :ok
        end

        :ets.delete(:player_positions, char_id)

        :ok

      _ ->
        :ok
    end
  end

  @doc """
  Gets all players in range of a position.
  Returns list of character IDs.
  """
  def get_players_in_range(map_name, x, y, range) do
    cells = cells_in_range(map_name, x, y, range)

    players =
      cells
      |> Enum.flat_map(fn cell ->
        case :ets.lookup(:spatial_index, cell) do
          [{^cell, player_set}] -> MapSet.to_list(player_set)
          [] -> []
        end
      end)
      |> Enum.uniq()

    players
    |> Enum.filter(fn char_id ->
      case :ets.lookup(:player_positions, char_id) do
        [{^char_id, {^map_name, px, py}}] ->
          distance(x, y, px, py) <= range

        _ ->
          false
      end
    end)
  end

  @doc """
  Gets all players in a specific grid cell.
  """
  def get_players_in_cell(map_name, cell_x, cell_y) do
    cell = {map_name, cell_x, cell_y}

    case :ets.lookup(:spatial_index, cell) do
      [{^cell, player_set}] -> MapSet.to_list(player_set)
      [] -> []
    end
  end

  @doc """
  Gets a player's current position.
  """
  def get_position(char_id) do
    case :ets.lookup(:player_positions, char_id) do
      [{^char_id, {map_name, x, y}}] ->
        {:ok, {x, y, map_name}}

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Gets all players on a specific map.
  """
  def get_players_on_map(map_name) do
    :ets.select(:player_positions, [
      {
        {:"$1", {:"$2", :_, :_}},
        [{:==, :"$2", map_name}],
        [:"$1"]
      }
    ])
  end

  @doc """
  Gets count of players on a map.
  """
  def count_players_on_map(map_name), do: length(get_players_on_map(map_name))

  defp cell_key(map_name, x, y) do
    {map_name, div(x, @cell_size), div(y, @cell_size)}
  end

  defp cells_in_range(map_name, x, y, range) do
    center_cx = div(x, @cell_size)
    center_cy = div(y, @cell_size)

    cell_range = div(range, @cell_size) + 1

    for cx <- (center_cx - cell_range)..(center_cx + cell_range),
        cy <- (center_cy - cell_range)..(center_cy + cell_range) do
      {map_name, cx, cy}
    end
  end

  defp distance(x1, y1, x2, y2), do: abs(x2 - x1) + abs(y2 - y1)
end
