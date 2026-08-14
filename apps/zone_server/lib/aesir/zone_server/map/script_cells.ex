defmodule Aesir.ZoneServer.Map.ScriptCells do
  @moduledoc "Applies script-owned (`setcell`) terrain contributions to the dynamic cell overlay."

  require Logger

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData

  @source_kind :npc_script
  @source_id 0

  @doc """
  Applies a `setcell` buildin over a rectangular region.

  `type` selects the trait mapping (`:walkable`, `:shootable`, `:icewall`);
  `flag` is `1` to set and `0` to clear. Unknown maps, types, or flags warn
  loudly and change nothing. Out-of-bounds cells are skipped with a warning.
  """
  @spec set(String.t(), {integer(), integer()}, {integer(), integer()}, atom(), integer()) :: :ok
  def set(map_name, {x1, y1}, {x2, y2}, type, flag) do
    with {:ok, %MapData{} = map_data} <- MapCache.get(map_name),
         {:ok, action} <- action_for(type, flag) do
      apply_rect(map_name, map_data, {x1, y1}, {x2, y2}, action)
    else
      _ ->
        Logger.warning(
          "setcell ignored: map=#{map_name} rect=#{x1},#{y1}-#{x2},#{y2} type=#{type} flag=#{flag}"
        )

        :ok
    end
  end

  defp apply_rect(map_name, map_data, {x1, y1}, {x2, y2}, action) do
    Enum.each(min(x1, x2)..max(x1, x2), fn x ->
      Enum.each(min(y1, y2)..max(y1, y2), fn y ->
        apply_cell(map_name, map_data, x, y, action)
      end)
    end)
  end

  defp apply_cell(map_name, map_data, x, y, action) do
    if in_bounds?(map_data, x, y) do
      apply_action(map_name, x, y, action)
    else
      Logger.warning("setcell out-of-bounds cell #{map_name} #{x},#{y} skipped")
    end
  end

  defp action_for(:walkable, 0), do: {:ok, {:put, [blocks_movement: true]}}
  defp action_for(:walkable, 1), do: {:ok, {:remove, [:blocks_movement]}}
  defp action_for(:shootable, 0), do: {:ok, {:put, [blocks_projectiles: true]}}
  defp action_for(:shootable, 1), do: {:ok, {:remove, [:blocks_projectiles]}}
  defp action_for(:icewall, 1), do: {:ok, {:put, [icewall: true]}}
  defp action_for(:icewall, 0), do: {:ok, {:remove, [:icewall]}}
  defp action_for(_type, _flag), do: :error

  defp apply_action(map_name, x, y, {:put, traits}) do
    Cell.put_traits(map_name, x, y, @source_kind, @source_id, traits)
  end

  defp apply_action(map_name, x, y, {:remove, [:blocks_movement] = keys}) do
    unless Cell.placeable?(map_name, x, y) do
      Logger.warning("setcell walkable,1 on base-unwalkable cell #{map_name} #{x},#{y}")
    end

    Cell.remove_traits(map_name, x, y, @source_kind, @source_id, keys)
  end

  defp apply_action(map_name, x, y, {:remove, keys}) do
    Cell.remove_traits(map_name, x, y, @source_kind, @source_id, keys)
  end

  defp in_bounds?(%MapData{xs: xs, ys: ys}, x, y), do: x >= 0 and x < xs and y >= 0 and y < ys
end
