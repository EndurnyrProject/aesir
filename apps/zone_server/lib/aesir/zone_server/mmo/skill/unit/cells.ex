defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Cells do
  @moduledoc """
  Materializes and removes a group's cell rows together with their secondary
  indexes: map terrain (`Map.Cell`), the targetable-unit registry and the
  spatial index.

  Every function runs inside `Skill.Unit.Manager`; `register_target/1`
  registers the calling process as the cell's owner.
  """

  alias Aesir.ZoneServer.Map.Cell, as: MapCell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Id
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapCombat
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Inserts one visible cell per group coordinate, with terrain and target
  indexes, on top of `stored`. Stops at the first failure, leaving the cells
  already stored for the caller to roll back.
  """
  @spec materialize_visible(Group.t(), [Cell.t()]) :: {:ok, [Cell.t()]} | {:error, term()}
  def materialize_visible(%Group{cells: cells} = group, stored) do
    Enum.reduce_while(cells, {:ok, stored, Id.first()}, fn {x, y}, {:ok, stored, start} ->
      with {:ok, cell_id} <- Id.allocate(start: start),
           :ok <- ensure_available(group, x, y),
           {:ok, cell} <-
             Cell.new(
               %{
                 cell_id: cell_id,
                 group_id: group.group_id,
                 map_name: group.map_name,
                 x: x,
                 y: y
               }
               |> Map.merge(attrs(group, {x, y}))
               |> Map.put(:flags, [:visible | List.wrap(Map.get(attrs(group, {x, y}), :flags))])
             ),
           :ok <- Storage.insert_cell(cell),
           :ok <- commit_terrain(cell),
           :ok <- register_target(cell) do
        {:cont, {:ok, [cell | stored], cell_id + 1}}
      else
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, stored, _start} -> {:ok, Enum.reverse(stored)}
      error -> error
    end
  end

  @doc "Drops the indexes of every stored cell of a group and deletes the group."
  @spec rollback_visible(non_neg_integer()) :: :ok
  def rollback_visible(group_id) do
    group_id |> Storage.get_cells_by_group() |> Enum.each(&remove_indexes/1)
    :ok = Storage.delete(group_id)
  end

  @doc "Deletes one cell row with its indexes."
  @spec remove(Cell.t()) :: :ok
  def remove(%Cell{} = cell) do
    :ok = remove_indexes(cell)
    :ok = Storage.delete_cell(cell.cell_id)
  end

  @doc "Drops a cell's terrain and target indexes, keeping its row."
  @spec remove_indexes(Cell.t()) :: :ok
  def remove_indexes(%Cell{} = cell) do
    :ok = remove_terrain(cell)
    :ok = remove_target(cell)
  end

  @doc "Returns a stored cell that can still be targeted."
  @spec fetch_targetable(non_neg_integer()) :: {:ok, Cell.t()} | {:error, atom()}
  def fetch_targetable(cell_id) do
    case Storage.get_cell(cell_id) do
      %Cell{state: %{trap_target: true}} = cell ->
        if Cell.flag?(cell, :targetable) and TrapCombat.targetable?(cell),
          do: {:ok, cell},
          else: {:error, :not_targetable}

      %Cell{} = cell when cell.hp > 0 ->
        if Cell.flag?(cell, :targetable), do: {:ok, cell}, else: {:error, :not_targetable}

      _ ->
        {:error, :not_found}
    end
  end

  @doc "Re-applies every stored cell's terrain and target indexes after a restart."
  @spec reconcile_indexes() :: :ok
  def reconcile_indexes do
    cells =
      Storage.all()
      |> Enum.flat_map(&Storage.get_cells_by_group(&1.group_id))
      |> Enum.filter(&terrain_cell?/1)

    Enum.each(cells, &commit_terrain/1)

    Storage.all()
    |> Enum.flat_map(&Storage.get_cells_by_group(&1.group_id))
    |> Enum.each(&register_target/1)

    :ok = MapCell.prune_source_kind(:skill_unit, Enum.map(cells, & &1.cell_id))

    :ok
  end

  @doc "Writes the cell's terrain traits into the map cell, if it has any."
  @spec commit_terrain(Cell.t()) :: :ok
  def commit_terrain(%Cell{} = cell) do
    case terrain_traits(cell) do
      [] ->
        :ok

      traits ->
        MapCell.put(cell.map_name, cell.x, cell.y, terrain_source(cell), cell.cell_id, traits)
    end
  end

  @doc "Registers a targetable cell as a unit owned by the calling process."
  @spec register_target(Cell.t()) :: :ok
  def register_target(%Cell{} = cell) do
    if Cell.flag?(cell, :targetable) and TrapCombat.targetable?(cell) do
      :ok = UnitRegistry.register_skill_unit(cell, self())
      SpatialIndex.add_skill_unit(cell)
    else
      :ok
    end
  end

  defp remove_target(%Cell{} = cell) do
    if Cell.flag?(cell, :targetable) do
      :ok = UnitRegistry.unregister_skill_unit(cell.cell_id)
      SpatialIndex.remove_skill_unit(cell.cell_id)
    else
      :ok
    end
  end

  defp remove_terrain(%Cell{} = cell),
    do: MapCell.delete_source(terrain_source(cell), cell.cell_id)

  defp attrs(%Group{state: state} = group, cell) do
    defaults = TrapCombat.cell_attrs(group)
    attrs = state |> Map.get(:cell_attrs, %{}) |> Map.get(cell, %{})

    Map.merge(defaults, attrs)
    |> Map.put(:state, Map.merge(Map.get(defaults, :state, %{}), Map.get(attrs, :state, %{})))
  end

  defp ensure_available(%Group{} = group, x, y) do
    if exclusive_terrain?(group) and MapCell.exclusive_contribution?(group.map_name, x, y) do
      {:error, :exclusive_terrain_overlap}
    else
      :ok
    end
  end

  defp exclusive_terrain?(%Group{state: %{exclusive_terrain: true}}), do: true
  defp exclusive_terrain?(_group), do: false

  defp terrain_source(%Cell{state: %{terrain_source: source}}) when is_atom(source), do: source
  defp terrain_source(_cell), do: :skill_unit

  defp terrain_cell?(cell), do: terrain_traits(cell) != []

  defp terrain_traits(cell) do
    []
    |> maybe_put(:blocks_movement, Cell.flag?(cell, :blocks_movement))
    |> maybe_put(:blocks_projectiles, Cell.flag?(cell, :blocks_projectiles))
    |> maybe_put(:icewall, Cell.flag?(cell, :icewall))
    |> maybe_put(:exclusive, exclusive_terrain_cell?(cell))
    |> maybe_put(
      :consumable_water,
      Cell.flag?(cell, :consumable_water),
      consumable_water_source(cell)
    )
  end

  defp consumable_water_source(%Cell{state: %{water_ball_token: true}, cell_id: cell_id}),
    do: {:water_ball, cell_id}

  defp consumable_water_source(%Cell{cell_id: cell_id}), do: cell_id

  defp exclusive_terrain_cell?(%Cell{state: %{exclusive_terrain: true}}), do: true
  defp exclusive_terrain_cell?(_cell), do: false

  defp maybe_put(traits, _key, false), do: traits
  defp maybe_put(traits, key, true), do: Keyword.put(traits, key, true)
  defp maybe_put(traits, key, true, value), do: Keyword.put(traits, key, value)
  defp maybe_put(traits, _key, false, _value), do: traits
end
