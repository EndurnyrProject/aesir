defmodule Aesir.ZoneServer.Unit.SpatialIndex do
  @moduledoc """
  ETS-based spatial indexing for O(1) player lookups.
  Uses grid cells for efficient range queries.
  """
  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  # 8x8 map cells per grid cell
  @cell_size 8

  # Generic Unit Functions

  @doc """
  Adds a unit to the spatial index.
  """
  def add_unit(unit_type, unit_id, x, y, map_name) do
    key = {unit_type, unit_id}
    :ets.insert(unit_positions_table(), {key, {map_name, x, y}})
    :ets.insert(map_units_table(), {{map_name, unit_type, unit_id}})

    cell_key = cell_key(map_name, x, y)

    units =
      case :ets.lookup(spatial_index_table(), cell_key) do
        [{^cell_key, existing}] -> existing
        [] -> %{}
      end

    units_of_type = Map.get(units, unit_type, MapSet.new())
    updated_units_of_type = MapSet.put(units_of_type, unit_id)
    updated = Map.put(units, unit_type, updated_units_of_type)

    :ets.insert(spatial_index_table(), {cell_key, updated})

    :ok
  end

  @doc """
  Updates a unit's position in the index.
  """
  def update_unit_position(unit_type, unit_id, new_x, new_y, new_map) do
    key = {unit_type, unit_id}

    case :ets.lookup(unit_positions_table(), key) do
      [{^key, {old_map, old_x, old_y}}] ->
        # Remove from old cell
        old_cell = cell_key(old_map, old_x, old_y)

        case :ets.lookup(spatial_index_table(), old_cell) do
          [{^old_cell, units}] ->
            units_of_type = Map.get(units, unit_type, MapSet.new())
            updated_units_of_type = MapSet.delete(units_of_type, unit_id)

            if MapSet.size(updated_units_of_type) == 0 do
              updated = Map.delete(units, unit_type)

              # credo:disable-for-next-line Credo.Check.Refactor.Nesting
              if map_size(updated) == 0 do
                :ets.delete(spatial_index_table(), old_cell)
              else
                :ets.insert(spatial_index_table(), {old_cell, updated})
              end
            else
              updated = Map.put(units, unit_type, updated_units_of_type)
              :ets.insert(spatial_index_table(), {old_cell, updated})
            end

          _ ->
            :ok
        end

        # Add to new cell
        new_cell = cell_key(new_map, new_x, new_y)

        units =
          case :ets.lookup(spatial_index_table(), new_cell) do
            [{^new_cell, existing}] -> existing
            [] -> %{}
          end

        units_of_type = Map.get(units, unit_type, MapSet.new())
        updated_units_of_type = MapSet.put(units_of_type, unit_id)
        updated = Map.put(units, unit_type, updated_units_of_type)

        :ets.insert(spatial_index_table(), {new_cell, updated})
        :ets.insert(unit_positions_table(), {key, {new_map, new_x, new_y}})
        move_map_membership(unit_type, unit_id, old_map, new_map)

        :ok

      _ ->
        add_unit(unit_type, unit_id, new_x, new_y, new_map)
    end
  end

  @doc """
  Removes a unit from the spatial index.
  """
  def remove_unit(unit_type, unit_id) do
    key = {unit_type, unit_id}

    case :ets.lookup(unit_positions_table(), key) do
      [{^key, {map_name, x, y}}] ->
        cell = cell_key(map_name, x, y)

        case :ets.lookup(spatial_index_table(), cell) do
          [{^cell, units}] ->
            units_of_type = Map.get(units, unit_type, MapSet.new())
            updated_units_of_type = MapSet.delete(units_of_type, unit_id)

            if MapSet.size(updated_units_of_type) == 0 do
              updated = Map.delete(units, unit_type)

              # credo:disable-for-next-line Credo.Check.Refactor.Nesting
              if map_size(updated) == 0 do
                :ets.delete(spatial_index_table(), cell)
              else
                :ets.insert(spatial_index_table(), {cell, updated})
              end
            else
              updated = Map.put(units, unit_type, updated_units_of_type)
              :ets.insert(spatial_index_table(), {cell, updated})
            end

          _ ->
            :ok
        end

        :ets.delete(unit_positions_table(), key)
        :ets.delete(map_units_table(), {map_name, unit_type, unit_id})

        :ok

      _ ->
        :ok
    end
  end

  @doc """
  Gets units of a specific type in range of a position.
  Returns list of unit IDs.
  """
  def get_units_in_range(unit_type, map_name, x, y, range) do
    cells = cells_in_range(map_name, x, y, range)

    units =
      cells
      |> Enum.flat_map(fn cell ->
        case :ets.lookup(spatial_index_table(), cell) do
          [{^cell, units_map}] ->
            units_map
            |> Map.get(unit_type, MapSet.new())
            |> MapSet.to_list()

          [] ->
            []
        end
      end)
      |> Enum.uniq()

    units
    |> Enum.filter(fn unit_id ->
      key = {unit_type, unit_id}

      case :ets.lookup(unit_positions_table(), key) do
        [{^key, {^map_name, ux, uy}}] ->
          distance(x, y, ux, uy) <= range

        _ ->
          false
      end
    end)
  end

  @doc """
  Gets units of a specific type within a rectangular area.
  Returns list of unit IDs.
  """
  @spec get_units_in_area(atom(), String.t(), integer(), integer(), integer(), integer()) ::
          [integer()]
  def get_units_in_area(unit_type, map_name, x1, y1, x2, y2) do
    x_min = min(x1, x2)
    x_max = max(x1, x2)
    y_min = min(y1, y2)
    y_max = max(y1, y2)

    units =
      map_name
      |> cells_in_area(x_min, y_min, x_max, y_max)
      |> Enum.flat_map(fn cell ->
        case :ets.lookup(spatial_index_table(), cell) do
          [{^cell, units_map}] ->
            units_map
            |> Map.get(unit_type, MapSet.new())
            |> MapSet.to_list()

          [] ->
            []
        end
      end)
      |> Enum.uniq()

    units
    |> Enum.filter(fn unit_id ->
      key = {unit_type, unit_id}

      case :ets.lookup(unit_positions_table(), key) do
        [{^key, {^map_name, ux, uy}}] ->
          ux >= x_min and ux <= x_max and uy >= y_min and uy <= y_max

        _ ->
          false
      end
    end)
  end

  @doc """
  Gets all units (of any type) in range of a position.
  Returns list of {unit_type, unit_id} tuples.
  """
  def get_all_units_in_range(map_name, x, y, range) do
    cells = cells_in_range(map_name, x, y, range)

    all_units =
      cells
      |> Enum.flat_map(fn cell ->
        case :ets.lookup(spatial_index_table(), cell) do
          [{^cell, units_map}] ->
            Enum.flat_map(units_map, fn {unit_type, unit_set} ->
              unit_set
              |> MapSet.to_list()
              # credo:disable-for-next-line Credo.Check.Refactor.Nesting
              |> Enum.map(fn unit_id -> {unit_type, unit_id} end)
            end)

          [] ->
            []
        end
      end)
      |> Enum.uniq()

    all_units
    |> Enum.filter(fn {unit_type, unit_id} ->
      key = {unit_type, unit_id}

      case :ets.lookup(unit_positions_table(), key) do
        [{^key, {^map_name, ux, uy}}] ->
          distance(x, y, ux, uy) <= range

        _ ->
          false
      end
    end)
  end

  @doc """
  Gets a unit's current position.
  """
  def get_unit_position(unit_type, unit_id) do
    key = {unit_type, unit_id}

    case :ets.lookup(unit_positions_table(), key) do
      [{^key, {map_name, x, y}}] ->
        {:ok, {x, y, map_name}}

      _ ->
        {:error, :not_found}
    end
  end

  @doc "Indexes a targetable skill-unit cell at its authoritative map position."
  @spec add_skill_unit(Aesir.ZoneServer.Mmo.Skill.Unit.Cell.t()) :: :ok
  def add_skill_unit(%Aesir.ZoneServer.Mmo.Skill.Unit.Cell{} = cell) do
    add_unit(:skill_unit, cell.cell_id, cell.x, cell.y, cell.map_name)
  end

  @doc "Removes a skill-unit cell from spatial queries."
  @spec remove_skill_unit(non_neg_integer()) :: :ok
  def remove_skill_unit(cell_id), do: remove_unit(:skill_unit, cell_id)

  @doc """
  Gets all units of a specific type on a map.

  Served from the `map_units` ordered_set, so the select walks only the
  `{map_name, unit_type, _}` prefix instead of scanning every unit position.
  """
  def get_units_on_map(unit_type, map_name) do
    :ets.select(map_units_table(), [
      {{{map_name, unit_type, :"$1"}}, [], [:"$1"]}
    ])
  end

  @doc """
  Gets count of units of a specific type on a map.
  """
  def count_units_on_map(unit_type, map_name) do
    :ets.select_count(map_units_table(), [
      {{{map_name, unit_type, :_}}, [], [true]}
    ])
  end

  @doc "Gets transient Homunculus gids in range of a position."
  @spec get_homunculi_in_range(String.t(), integer(), integer(), non_neg_integer()) :: [integer()]
  def get_homunculi_in_range(map_name, x, y, range) do
    get_units_in_range(:homunculus, map_name, x, y, range)
  end

  # Player-specific wrapper functions for backward compatibility

  @doc """
  Adds a player to the spatial index.
  This is a wrapper for backward compatibility.
  """
  def add_player(char_id, x, y, map_name) do
    add_unit(:player, char_id, x, y, map_name)
  end

  @doc """
  Updates a player's position in the index.
  This is a wrapper for backward compatibility.
  """
  def update_position(char_id, new_x, new_y, new_map) do
    update_unit_position(:player, char_id, new_x, new_y, new_map)
  end

  @doc """
  Removes a player from the spatial index.
  This is a wrapper for backward compatibility.
  """
  def remove_player(char_id) do
    remove_unit(:player, char_id)
  end

  @doc """
  Gets all players in range of a position.
  Returns list of character IDs.
  This is a wrapper for backward compatibility.
  """
  def get_players_in_range(map_name, x, y, range) do
    get_units_in_range(:player, map_name, x, y, range)
  end

  @doc """
  Gets all players within a rectangular area.
  Returns list of character IDs.
  This is a wrapper for backward compatibility.
  """
  @spec get_players_in_area(String.t(), integer(), integer(), integer(), integer()) ::
          [integer()]
  def get_players_in_area(map_name, x1, y1, x2, y2) do
    get_units_in_area(:player, map_name, x1, y1, x2, y2)
  end

  @doc """
  Gets all players in a specific grid cell.
  This is a wrapper for backward compatibility.
  """
  def get_players_in_cell(map_name, cell_x, cell_y) do
    cell = {map_name, cell_x, cell_y}

    case :ets.lookup(spatial_index_table(), cell) do
      [{^cell, units_map}] ->
        units_map
        |> Map.get(:player, MapSet.new())
        |> MapSet.to_list()

      [] ->
        []
    end
  end

  @doc """
  Gets a player's current position.
  This is a wrapper for backward compatibility.
  """
  def get_position(char_id) do
    get_unit_position(:player, char_id)
  end

  @doc """
  Gets all players on a specific map.
  This is a wrapper for backward compatibility.
  """
  def get_players_on_map(map_name) do
    get_units_on_map(:player, map_name)
  end

  @doc """
  Gets count of players on a map.
  This is a wrapper for backward compatibility.
  """
  def count_players_on_map(map_name) do
    count_units_on_map(:player, map_name)
  end

  defp move_map_membership(_unit_type, _unit_id, same_map, same_map), do: :ok

  defp move_map_membership(unit_type, unit_id, old_map, new_map) do
    :ets.delete(map_units_table(), {old_map, unit_type, unit_id})
    :ets.insert(map_units_table(), {{new_map, unit_type, unit_id}})
    :ok
  end

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

  defp cells_in_area(map_name, x_min, y_min, x_max, y_max) do
    for cx <- div(x_min, @cell_size)..div(x_max, @cell_size),
        cy <- div(y_min, @cell_size)..div(y_max, @cell_size) do
      {map_name, cx, cy}
    end
  end

  defp distance(x1, y1, x2, y2), do: abs(x2 - x1) + abs(y2 - y1)

  @doc """
  Checks if observer can see target (O(1) lookup).
  """
  def can_see?(observer_id, target_id) do
    case :ets.lookup(visibility_pairs_table(), {observer_id, target_id}) do
      [{{^observer_id, ^target_id}, true}] -> true
      _ -> false
    end
  end

  @doc """
  Updates visibility between two players (bidirectional).
  """
  def update_visibility(player1_id, player2_id, visible) do
    if visible do
      :ets.insert(visibility_pairs_table(), {{player1_id, player2_id}, true})
      :ets.insert(visibility_pairs_table(), {{player2_id, player1_id}, true})
    else
      :ets.delete(visibility_pairs_table(), {player1_id, player2_id})
      :ets.delete(visibility_pairs_table(), {player2_id, player1_id})
    end

    :ok
  end

  @doc """
  Gets all players visible to the given player.
  """
  def get_visible_players(observer_id) do
    :ets.select(visibility_pairs_table(), [
      {
        {{observer_id, :"$1"}, true},
        [],
        [:"$1"]
      }
    ])
  end

  @doc """
  Clears all visibility entries for a player (used on disconnect).
  """
  def clear_visibility(player_id) do
    visible_to_player = get_visible_players(player_id)

    Enum.each(visible_to_player, fn other_id ->
      update_visibility(player_id, other_id, false)
    end)
  end

  # ETS table accessors
  # Using the same tables but with updated structure to support unit types
  defp unit_positions_table, do: table_for(:player_positions)
  defp spatial_index_table, do: table_for(:spatial_index)
  defp visibility_pairs_table, do: table_for(:visibility_pairs)
  defp map_units_table, do: table_for(:map_units)
end
