defmodule Aesir.ZoneServer.Map.Cell do
  @moduledoc "Read facade for immutable GAT terrain and dynamic source contributions."

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData

  @uint32_max 0xFFFF_FFFF

  defmodule WaterSource do
    @moduledoc "A Water Ball source and whether it is permanent terrain or a consumable cell."

    use TypedStruct

    typedstruct do
      field :origin, :base | :skill_unit, enforce: true
      field :cell_id, non_neg_integer() | nil, enforce: true
    end
  end

  @type contribution :: %{
          optional(:blocks_movement) => boolean(),
          optional(:blocks_projectiles) => boolean(),
          optional(:consumable_water) => non_neg_integer()
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
      :ets.insert(table_for(:dynamic_cell_contributions), {key, contribution})
      :ets.insert(table_for(:dynamic_cell_source_index), {{source_kind, source_id}, key})
      :ok
    end)
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

    base?(map_name, x, y, &GatType.is_walkable?/1) and
      not Enum.any?(contributions(map_name, x, y), &Map.get(&1, :blocks_movement, false))
  end

  @doc "Returns whether base terrain or any contribution blocks projectiles."
  @spec blocks_projectiles?(String.t(), integer(), integer()) :: boolean()
  def blocks_projectiles?(map_name, x, y) do
    map_name = canonical_map_name(map_name)

    not base?(map_name, x, y, fn gat_type -> not GatType.blocks_projectile?(gat_type) end) or
      Enum.any?(contributions(map_name, x, y), &Map.get(&1, :blocks_projectiles, false))
  end

  @doc "Returns whether a skill-unit may be placed on the effective terrain."
  @spec placeable?(String.t(), integer(), integer()) :: boolean()
  def placeable?(map_name, x, y), do: traversable?(map_name, x, y)

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

  @doc "Returns a permanent base-water or consumable skill-unit-water source at the cell."
  @spec water_source(String.t(), integer(), integer()) :: WaterSource.t() | nil
  def water_source(map_name, x, y) do
    map_name = canonical_map_name(map_name)

    case base_cell(map_name, x, y) do
      nil ->
        nil

      gat_type ->
        water_source_for_gat(map_name, x, y, gat_type)
    end
  end

  @doc "Returns whether another Ice Wall already owns the coordinate."
  @spec ice_wall_overlap?(String.t(), integer(), integer()) :: boolean()
  def ice_wall_overlap?(map_name, x, y) do
    map_name = canonical_map_name(map_name)

    :ets.match_object(
      table_for(:dynamic_cell_contributions),
      {{map_name, x, y, :icewall, :_}, :_}
    ) != []
  end

  defp contributions(map_name, x, y) do
    :ets.match_object(table_for(:dynamic_cell_contributions), {{map_name, x, y, :_, :_}, :_})
    |> Enum.map(fn {_key, contribution} -> contribution end)
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

  defp base?(map_name, x, y, predicate) do
    case base_cell(map_name, x, y) do
      gat_type when is_integer(gat_type) -> predicate.(gat_type)
      nil -> false
    end
  end

  defp water_source_for_gat(map_name, x, y, gat_type) do
    case Enum.find_value(contributions(map_name, x, y), &Map.get(&1, :consumable_water)) do
      nil -> if GatType.is_water?(gat_type), do: %WaterSource{origin: :base, cell_id: nil}
      cell_id -> %WaterSource{origin: :skill_unit, cell_id: cell_id}
    end
  end

  defp delete_at(map_name, x, y, source_kind, source_id) do
    key = {map_name, x, y, source_kind, source_id}

    transaction(fn ->
      :ets.delete(table_for(:dynamic_cell_contributions), key)
      :ets.delete_object(table_for(:dynamic_cell_source_index), {{source_kind, source_id}, key})
      :ok
    end)
  end

  defp delete_source_now(source_kind, source_id) do
    table_for(:dynamic_cell_source_index)
    |> :ets.lookup({source_kind, source_id})
    |> Enum.each(fn {{^source_kind, ^source_id}, key} ->
      :ets.delete(table_for(:dynamic_cell_contributions), key)
      :ets.delete_object(table_for(:dynamic_cell_source_index), {{source_kind, source_id}, key})
    end)

    :ok
  end

  defp base_cell(map_name, x, y) do
    with {:ok, %MapData{} = map} <- MapCache.get(map_name),
         gat_type when is_integer(gat_type) <- MapData.get_cell(map, x, y) do
      gat_type
    else
      _ -> nil
    end
  end

  defp canonical_map_name(map_name), do: String.replace_suffix(map_name, ".gat", "")

  defp transaction(fun) do
    :global.trans({__MODULE__, table_for(:dynamic_cell_contributions)}, fun)
  end

  defp validate_contribution!(contribution) do
    unless Map.keys(contribution) -- [:blocks_movement, :blocks_projectiles, :consumable_water] ==
             [] and
             is_boolean(Map.get(contribution, :blocks_movement, false)) and
             is_boolean(Map.get(contribution, :blocks_projectiles, false)) and
             (not Map.has_key?(contribution, :consumable_water) or
                contribution.consumable_water in 1..@uint32_max) do
      raise ArgumentError, "invalid dynamic terrain contribution"
    end
  end
end
