defmodule Aesir.ZoneServer.Mmo.Skill.Unit.WaterBall do
  @moduledoc """
  The invisible Water Ball sequence: one consumable-water cell per water
  source around the caster, fired in order, each interval claiming the next
  cell until none is left.

  Every function runs inside `Skill.Unit.Manager`.
  """

  alias Aesir.ZoneServer.Map.Cell, as: MapCell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cells
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.GroupLifecycle
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Handler
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Id
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  @doc """
  Stores an invisible sequence group and one cell per water source among
  `cells`, in order. A source that is another skill unit's cell is consumed
  out of its group; one that is itself a Water Ball cell is skipped.
  """
  @spec register_sequence(Group.t(), [Group.cell()]) ::
          {:ok, Group.t()} | {:error, :no_water_source | :visible_sequence | term()}
  def register_sequence(%Group{visibility: :none} = group, cells) do
    with {:ok, _group} <- GroupLifecycle.register_invisible(group),
         {:ok, cell_count} <- materialize_cells(group, cells),
         true <- cell_count > 0 do
      {:ok, group}
    else
      false ->
        :ok = Storage.delete(group.group_id)
        {:error, :no_water_source}

      {:error, _reason} = error ->
        Cells.rollback_visible(group.group_id)
        error
    end
  end

  def register_sequence(_group, _cells), do: {:error, :visible_sequence}

  @doc """
  One interval of a sequence group: the handler's `on_interval` fires the
  next ball, then the fired cell is claimed; a sequence with no cell left is
  torn down.
  """
  @spec run_interval(Group.t(), integer()) :: :ok
  def run_interval(%Group{} = group, now) do
    if Storage.get_cells_by_group(group.group_id) == [] do
      GroupLifecycle.cleanup(group)
    else
      case Handler.for_group(group) do
        {:ok, module} -> invoke_interval(module, group, now)
        :error -> GroupLifecycle.callback_failed(group, :on_interval, :missing_handler, nil)
      end
    end
  end

  defp invoke_interval(module, group, now) do
    case Handler.invoke(module, :on_interval, [group, now]) do
      {:ok, {:ok, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
        advance(updated, now, module)

      {:ok, {:ok, %Group{group_id: group_id}}} ->
        GroupLifecycle.callback_failed(group, :on_interval, {:foreign_group_id, group_id}, module)

      {:ok, {:expire, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
        GroupLifecycle.cleanup(updated, module)

      {:ok, {:expire, %Group{group_id: group_id}}} ->
        GroupLifecycle.callback_failed(group, :on_interval, {:foreign_group_id, group_id}, module)

      {:ok, result} ->
        GroupLifecycle.callback_failed(group, :on_interval, {:invalid_return, result}, module)

      {:error, reason} ->
        GroupLifecycle.callback_failed(group, :on_interval, reason, module)
    end
  end

  defp advance(%Group{state: %{water_ball_fired: false}} = group, now, _module) do
    Storage.update(%{group | next_tick_at: now + group.interval})
  end

  defp advance(group, now, module) do
    case claim_next_cell(group) do
      {:ok, group} -> GroupLifecycle.update_after_interval(group, now, module)
      :empty -> GroupLifecycle.cleanup(group, module)
    end
  end

  defp claim_next_cell(%Group{} = group) do
    case Enum.min_by(
           Storage.get_cells_by_group(group.group_id),
           &sequence_index/1,
           fn -> nil end
         ) do
      %Cell{} = cell ->
        :ok = Cells.remove(cell)
        {:ok, group}

      nil ->
        :empty
    end
  end

  defp sequence_index(%Cell{state: %{water_ball_sequence_index: sequence_index}}),
    do: sequence_index

  defp materialize_cells(group, cells) do
    cells
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, 0}, fn {{x, y}, sequence_index}, {:ok, cell_count} ->
      case materialize_cell(group, x, y, sequence_index) do
        {:ok, _cell} -> {:cont, {:ok, cell_count + 1}}
        :skip -> {:cont, {:ok, cell_count}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp materialize_cell(group, x, y, sequence_index) do
    with :ok <- consume_water_source(MapCell.water_source(group.map_name, x, y)) do
      create_cell(group, x, y, sequence_index)
    end
  end

  defp consume_water_source(%MapCell.WaterSource{origin: :base}), do: :ok

  defp consume_water_source(%MapCell.WaterSource{origin: :skill_unit, cell_id: source_id}) do
    with %Cell{} = source <- Storage.get_cell(source_id),
         %Group{} = owner <- Storage.get(source.group_id) do
      GroupLifecycle.remove_cells(owner, MapSet.new([{source.x, source.y}]))
      :ok
    else
      nil -> :skip
    end
  end

  defp consume_water_source(%MapCell.WaterSource{origin: :water_ball}), do: :skip
  defp consume_water_source(nil), do: :skip

  defp create_cell(group, x, y, sequence_index) do
    with {:ok, cell_id} <- Id.allocate(),
         {:ok, cell} <-
           Cell.new(%{
             cell_id: cell_id,
             group_id: group.group_id,
             map_name: group.map_name,
             x: x,
             y: y,
             flags: [:consumable_water],
             state: %{water_ball_token: true, water_ball_sequence_index: sequence_index}
           }),
         :ok <- Storage.insert_cell(cell),
         :ok <- Cells.commit_terrain(cell) do
      {:ok, cell}
    end
  end
end
