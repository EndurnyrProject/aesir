defmodule Aesir.ZoneServer.Map.Cell do
  @moduledoc "Read facade for immutable GAT terrain and dynamic source contributions."

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData

  @uint32_max 0xFFFF_FFFF

  defmodule WaterSource do
    @moduledoc "A Water Ball source and whether it is permanent terrain or a consumable cell."

    @enforce_keys [:origin, :cell_id]
    defstruct [:origin, :cell_id]

    @type t() :: %__MODULE__{
            origin: :base | :skill_unit | :water_ball,
            cell_id: non_neg_integer() | nil
          }
  end

  @type contribution :: %{
          optional(:blocks_movement) => boolean(),
          optional(:blocks_projectiles) => boolean(),
          optional(:consumable_water) => non_neg_integer() | {:water_ball, non_neg_integer()},
          optional(:exclusive) => boolean(),
          optional(:icewall) => boolean()
        }

  @doc "Adds or replaces one source-owned terrain contribution."
  @spec put(String.t(), integer(), integer(), atom(), non_neg_integer(), keyword()) :: :ok
  def put(map_name, x, y, source_kind, source_id, traits)
      when is_binary(map_name) and is_integer(x) and x >= 0 and is_integer(y) and y >= 0 and
             is_atom(source_kind) and is_integer(source_id) and source_id >= 0 do
    map_name = canonical_map_name(map_name)
    contribution = Map.new(traits)
    validate_contribution!(contribution)
    key = {map_name, x, y, source_kind, source_id}

    transaction(fn ->
      write_contribution(key, source_kind, source_id, map_name, x, y, contribution)
      :ok
    end)
  end

  @doc "Merges traits into a source-owned terrain contribution."
  @spec put_traits(String.t(), integer(), integer(), atom(), non_neg_integer(), keyword()) :: :ok
  def put_traits(map_name, x, y, source_kind, source_id, traits)
      when is_binary(map_name) and is_integer(x) and x >= 0 and is_integer(y) and y >= 0 and
             is_atom(source_kind) and is_integer(source_id) and source_id >= 0 do
    map_name = canonical_map_name(map_name)
    key = {map_name, x, y, source_kind, source_id}

    transaction(fn ->
      merged = Map.merge(current_contribution(key), Map.new(traits))
      validate_contribution!(merged)
      write_contribution(key, source_kind, source_id, map_name, x, y, merged)
      :ok
    end)
  end

  @doc "Removes trait keys from a source-owned contribution, deleting it when it empties."
  @spec remove_traits(String.t(), integer(), integer(), atom(), non_neg_integer(), [atom()]) ::
          :ok
  def remove_traits(map_name, x, y, source_kind, source_id, keys)
      when is_binary(map_name) and is_integer(x) and x >= 0 and is_integer(y) and y >= 0 and
             is_atom(source_kind) and is_integer(source_id) and source_id >= 0 do
    map_name = canonical_map_name(map_name)
    key = {map_name, x, y, source_kind, source_id}

    transaction(fn ->
      apply_traits_removal(
        key,
        current_contribution(key),
        keys,
        source_kind,
        source_id,
        map_name,
        x,
        y
      )

      :ok
    end)
  end

  defp apply_traits_removal(key, contribution, keys, source_kind, source_id, map_name, x, y) do
    case Map.drop(contribution, keys) do
      remaining when map_size(remaining) == 0 ->
        delete_contribution(key, source_kind, source_id, map_name, x, y)

      remaining ->
        write_contribution(key, source_kind, source_id, map_name, x, y, remaining)
    end
  end

  @doc "Removes one contribution without changing the immutable base GAT cell."
  @spec delete(String.t(), integer(), integer(), atom(), non_neg_integer()) :: :ok
  def delete(map_name, x, y, source_kind, source_id) do
    map_name
    |> canonical_map_name()
    |> delete_at(x, y, source_kind, source_id)
  end

  @doc "Removes every contribution owned by one source."
  @spec delete_source(atom(), non_neg_integer()) :: :ok
  def delete_source(source_kind, source_id) do
    transaction(fn -> delete_source_now(source_kind, source_id) end)
  end

  @doc "Clears runtime terrain before manager reconciliation after a restart."
  @spec clear() :: :ok
  def clear do
    transaction(fn ->
      :ets.delete_all_objects(table_for(:dynamic_cell_contributions))
      :ets.delete_all_objects(table_for(:dynamic_cell_source_index))
      :ets.delete_all_objects(table_for(:dynamic_cell_coordinate_index))
      :ok
    end)
  end

  @doc "Removes sources of a kind that are absent from the authoritative source IDs."
  @spec prune_source_kind(atom(), [non_neg_integer()]) :: :ok
  def prune_source_kind(source_kind, source_ids) do
    retained = MapSet.new(source_ids)

    transaction(fn ->
      table_for(:dynamic_cell_source_index)
      |> :ets.match_object({{source_kind, :_}, :_})
      |> Enum.map(fn {{^source_kind, source_id}, _key} -> source_id end)
      |> Enum.uniq()
      |> Enum.reject(&MapSet.member?(retained, &1))
      |> Enum.each(&delete_source_now(source_kind, &1))

      :ok
    end)
  end

  @doc "Returns whether a cell permits traversal after all contributions are applied."
  @spec traversable?(String.t(), integer(), integer()) :: boolean()
  def traversable?(map_name, x, y) do
    map_name = canonical_map_name(map_name)

    base?(map_name, x, y, &MapData.walkable?/3) and
      not Enum.any?(contributions(map_name, x, y), &Map.get(&1, :blocks_movement, false))
  end

  @doc "Returns whether base terrain or any contribution blocks projectiles."
  @spec blocks_projectiles?(String.t(), integer(), integer()) :: boolean()
  def blocks_projectiles?(map_name, x, y) do
    map_name = canonical_map_name(map_name)

    base?(map_name, x, y, &MapData.blocks_projectile?/3, true) or
      Enum.any?(contributions(map_name, x, y), &Map.get(&1, :blocks_projectiles, false))
  end

  @doc """
  Returns whether a single-cell step from `from` to `to` is traversable.

  A diagonal step additionally requires both orthogonal side cells to be
  traversable, matching rAthena's no-corner-cut rule (`path.cpp`): a unit may
  not slip between two diagonally-adjacent blocked cells (e.g. a diagonal
  Ice Wall).
  """
  @spec step_traversable?(String.t(), {integer(), integer()}, {integer(), integer()}) :: boolean()
  def step_traversable?(map_name, {from_x, from_y}, {to_x, to_y}) do
    dx = to_x - from_x
    dy = to_y - from_y

    traversable?(map_name, to_x, to_y) and
      (dx == 0 or dy == 0 or
         (traversable?(map_name, from_x + dx, from_y) and
            traversable?(map_name, from_x, from_y + dy)))
  end

  @doc "Returns whether a skill-unit may be placed on base terrain."
  @spec placeable?(String.t(), integer(), integer()) :: boolean()
  def placeable?(map_name, x, y) do
    map_name
    |> canonical_map_name()
    |> base?(x, y, &MapData.walkable?/3)
  end

  @doc "Returns a random traversable cell within the map's bounds."
  @spec random_traversable(String.t(), integer()) ::
          {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, :no_walkable_cell | :not_found}
  def random_traversable(map_name, max_attempts \\ 100)

  def random_traversable(_map_name, max_attempts)
      when not is_integer(max_attempts) or max_attempts <= 0,
      do: {:error, :no_walkable_cell}

  def random_traversable(map_name, max_attempts) do
    map_name = canonical_map_name(map_name)

    with {:ok, %MapData{xs: xs, ys: ys}} <- MapCache.get(map_name) do
      random_traversable(map_name, xs, ys, max_attempts)
    end
  end

  @doc "Returns whether an active terrain contribution blocks movement at a cell."
  @spec dynamically_blocked?(String.t(), integer(), integer()) :: boolean()
  def dynamically_blocked?(map_name, x, y) do
    map_name
    |> canonical_map_name()
    |> contributions(x, y)
    |> Enum.any?(&Map.get(&1, :blocks_movement, false))
  end

  @doc "Returns whether an active terrain contribution marks the cell as an icewall fence."
  @spec icewall?(String.t(), integer(), integer()) :: boolean()
  def icewall?(map_name, x, y) do
    map_name
    |> canonical_map_name()
    |> contributions(x, y)
    |> Enum.any?(&Map.get(&1, :icewall, false))
  end

  @doc "Returns a permanent, temporary, or Water Ball token source at the cell."
  @spec water_source(String.t(), integer(), integer()) :: WaterSource.t() | nil
  def water_source(map_name, x, y) do
    map_name = canonical_map_name(map_name)

    case base_map(map_name, x, y) do
      nil ->
        nil

      map ->
        water_source_for_map(map_name, x, y, map)
    end
  end

  @doc "Returns whether an exclusive terrain contribution owns the coordinate."
  @spec exclusive_contribution?(String.t(), integer(), integer()) :: boolean()
  def exclusive_contribution?(map_name, x, y) do
    map_name = canonical_map_name(map_name)

    Enum.any?(contributions(map_name, x, y), &Map.get(&1, :exclusive, false))
  end

  defp contributions(map_name, x, y) do
    contribution_table = table_for(:dynamic_cell_contributions)

    :ets.lookup(table_for(:dynamic_cell_coordinate_index), {map_name, x, y})
    |> Enum.flat_map(fn {_coordinate, key} ->
      case :ets.lookup(contribution_table, key) do
        [{^key, contribution}] -> [contribution]
        [] -> []
      end
    end)
  end

  defp random_traversable(_map_name, _xs, _ys, 0), do: {:error, :no_walkable_cell}

  defp random_traversable(map_name, xs, ys, attempts) do
    x = :rand.uniform(xs) - 1
    y = :rand.uniform(ys) - 1

    if traversable?(map_name, x, y) do
      {:ok, {x, y}}
    else
      random_traversable(map_name, xs, ys, attempts - 1)
    end
  end

  defp base?(map_name, x, y, predicate, fallback \\ false) do
    case MapCache.get(map_name) do
      {:ok, %MapData{} = map} -> predicate.(map, x, y)
      _ -> fallback
    end
  end

  defp water_source_for_map(map_name, x, y, map) do
    sources = contributions(map_name, x, y) |> Enum.map(&Map.get(&1, :consumable_water))

    case Enum.find(sources, &is_integer/1) || Enum.find(sources, &match?({:water_ball, _}, &1)) do
      nil -> if MapData.water?(map, x, y), do: %WaterSource{origin: :base, cell_id: nil}
      cell_id when is_integer(cell_id) -> %WaterSource{origin: :skill_unit, cell_id: cell_id}
      {:water_ball, cell_id} -> %WaterSource{origin: :water_ball, cell_id: cell_id}
    end
  end

  defp delete_at(map_name, x, y, source_kind, source_id) do
    key = {map_name, x, y, source_kind, source_id}

    transaction(fn ->
      delete_contribution(key, source_kind, source_id, map_name, x, y)
      :ok
    end)
  end

  defp delete_source_now(source_kind, source_id) do
    table_for(:dynamic_cell_source_index)
    |> :ets.lookup({source_kind, source_id})
    |> Enum.each(fn {{^source_kind, ^source_id}, key} ->
      :ets.delete(table_for(:dynamic_cell_contributions), key)
      :ets.delete_object(table_for(:dynamic_cell_source_index), {{source_kind, source_id}, key})
      {map_name, x, y, ^source_kind, ^source_id} = key
      :ets.delete_object(table_for(:dynamic_cell_coordinate_index), {{map_name, x, y}, key})
    end)

    :ok
  end

  defp current_contribution(key) do
    case :ets.lookup(table_for(:dynamic_cell_contributions), key) do
      [{^key, contribution}] -> contribution
      [] -> %{}
    end
  end

  defp write_contribution(key, source_kind, source_id, map_name, x, y, contribution) do
    :ets.insert(table_for(:dynamic_cell_contributions), {key, contribution})
    :ets.insert(table_for(:dynamic_cell_source_index), {{source_kind, source_id}, key})
    :ets.insert(table_for(:dynamic_cell_coordinate_index), {{map_name, x, y}, key})
    :ok
  end

  defp delete_contribution(key, source_kind, source_id, map_name, x, y) do
    :ets.delete(table_for(:dynamic_cell_contributions), key)
    :ets.delete_object(table_for(:dynamic_cell_source_index), {{source_kind, source_id}, key})
    :ets.delete_object(table_for(:dynamic_cell_coordinate_index), {{map_name, x, y}, key})
    :ok
  end

  defp base_map(map_name, x, y) do
    with {:ok, %MapData{} = map} <- MapCache.get(map_name),
         cell when not is_nil(cell) <- MapData.get_cell(map, x, y) do
      map
    else
      _ -> nil
    end
  end

  defp canonical_map_name(map_name), do: String.replace_suffix(map_name, ".gat", "")

  defp transaction(fun) do
    :global.trans({__MODULE__, table_for(:dynamic_cell_contributions)}, fun)
  end

  defp validate_contribution!(contribution) do
    unless Map.keys(contribution) --
             [:blocks_movement, :blocks_projectiles, :consumable_water, :exclusive, :icewall] ==
             [] and
             is_boolean(Map.get(contribution, :blocks_movement, false)) and
             is_boolean(Map.get(contribution, :blocks_projectiles, false)) and
             is_boolean(Map.get(contribution, :exclusive, false)) and
             is_boolean(Map.get(contribution, :icewall, false)) and
             valid_consumable_water?(Map.get(contribution, :consumable_water)) do
      raise ArgumentError, "invalid dynamic terrain contribution"
    end
  end

  defp valid_consumable_water?(nil), do: true
  defp valid_consumable_water?(cell_id) when cell_id in 1..@uint32_max, do: true
  defp valid_consumable_water?({:water_ball, cell_id}) when cell_id in 1..@uint32_max, do: true
  defp valid_consumable_water?(_value), do: false
end
