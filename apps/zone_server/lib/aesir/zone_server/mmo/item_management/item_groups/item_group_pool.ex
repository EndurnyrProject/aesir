defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.ItemGroupPool do
  @moduledoc """
  Owns the depleted copy counts for one item group's shared-pool subgroups.

  Pools start lazily, serialize draws and rollbacks, and stop after five minutes
  without a call. The idle timeout is a tuning constant.
  """
  use GenServer

  alias Aesir.Commons.Cluster
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.SubGroup

  @idle_timeout :timer.minutes(5)

  @type state() :: %{
          catalog: Group.t(),
          subs: %{non_neg_integer() => %{pos_integer() => non_neg_integer()}}
        }

  @doc "Starts the pool owner for a group if necessary and returns its pid."
  @spec ensure_pool(atom()) :: pid()
  def ensure_pool(key) do
    case Horde.DynamicSupervisor.start_child(
           Cluster.item_group_pool_supervisor(),
           {__MODULE__, key: key}
         ) do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        pid

      {:error, reason} ->
        raise "failed to start item group pool #{inspect(key)}: #{inspect(reason)}"
    end
  end

  @doc "Draws item ids from a subgroup's remaining shared-pool copies."
  @spec draw(atom(), non_neg_integer(), pos_integer()) ::
          {:ok, [pos_integer()]} | {:error, :empty}
  def draw(group_key, sub, count) when count > 0 do
    group_key
    |> ensure_pool()
    |> GenServer.call({:draw, sub, count})
  end

  @doc "Returns drawn item-id copies to a shared-pool subgroup."
  @spec rollback(atom(), non_neg_integer(), [pos_integer()]) :: :ok
  def rollback(group_key, sub, item_ids) do
    group_key
    |> ensure_pool()
    |> GenServer.call({:rollback, sub, item_ids})
  end

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    key = Keyword.fetch!(opts, :key)
    GenServer.start_link(__MODULE__, key, name: via_name(key))
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    Supervisor.child_spec(%{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}},
      restart: :transient
    )
  end

  @impl true
  def init(key) do
    {:ok, catalog} = ItemGroups.fetch(key)
    {:ok, %{catalog: catalog, subs: seed_subgroups(catalog)}, @idle_timeout}
  end

  @impl true
  def handle_call({:draw, sub, count}, _from, state) do
    with {:ok, remaining} <- Map.fetch(state.subs, sub),
         {:ok, item_ids, remaining} <- take_weighted(remaining, refill(state.catalog, sub), count) do
      {:reply, {:ok, item_ids}, put_in(state, [:subs, sub], remaining), @idle_timeout}
    else
      :error -> {:reply, {:error, :empty}, state, @idle_timeout}
      {:error, :empty} -> {:reply, {:error, :empty}, state, @idle_timeout}
    end
  end

  def handle_call({:rollback, sub, item_ids}, _from, state) do
    counts = state.subs |> Map.fetch!(sub) |> return_copies(item_ids)
    {:reply, :ok, put_in(state, [:subs, sub], counts), @idle_timeout}
  end

  @impl true
  def handle_info(:timeout, state), do: {:stop, :normal, state}

  @spec via_name(atom()) :: {:via, module(), {module(), term()}}
  defp via_name(key),
    do: {:via, Horde.Registry, {Cluster.registry(), {:item_group_pool, key}}}

  @spec seed_subgroups(Group.t()) :: map()
  defp seed_subgroups(catalog) do
    catalog.subgroups
    |> Enum.filter(&(&1.algorithm == :shared_pool))
    |> Map.new(&{&1.number, seed_counts(&1)})
  end

  @spec refill(Group.t(), non_neg_integer()) :: map()
  defp refill(catalog, sub) do
    case Enum.find(catalog.subgroups, &(&1.number == sub and &1.algorithm == :shared_pool)) do
      %SubGroup{} = subgroup -> seed_counts(subgroup)
      nil -> %{}
    end
  end

  @spec seed_counts(SubGroup.t()) :: map()
  defp seed_counts(subgroup) do
    Enum.reduce(subgroup.entries, %{}, fn entry, counts ->
      if entry.rate > 0 do
        Map.update(counts, entry.item_id, entry.rate, &(&1 + entry.rate))
      else
        counts
      end
    end)
  end

  @spec take_weighted(map(), map(), pos_integer(), [pos_integer()]) ::
          {:ok, [pos_integer()], map()} | {:error, :empty}
  defp take_weighted(counts, refill, count, picked \\ [])
  defp take_weighted(counts, _refill, 0, picked), do: {:ok, Enum.reverse(picked), counts}

  defp take_weighted(counts, refill, count, picked) when map_size(counts) == 0 do
    if map_size(refill) == 0 do
      {:error, :empty}
    else
      take_weighted(refill, refill, count, picked)
    end
  end

  defp take_weighted(counts, refill, count, picked) do
    item_id = weighted_pick(counts, :rand.uniform(Enum.sum(Map.values(counts))))
    remaining = decrement(counts, item_id)
    take_weighted(remaining, refill, count - 1, [item_id | picked])
  end

  @spec weighted_pick(map(), pos_integer()) :: pos_integer()
  defp weighted_pick(counts, roll) do
    Enum.reduce_while(counts, roll, fn {item_id, copies}, remaining ->
      if remaining <= copies do
        {:halt, item_id}
      else
        {:cont, remaining - copies}
      end
    end)
  end

  @spec decrement(map(), pos_integer()) :: map()
  defp decrement(counts, item_id) do
    case counts[item_id] do
      1 -> Map.delete(counts, item_id)
      copies -> Map.put(counts, item_id, copies - 1)
    end
  end

  @spec return_copies(map(), [pos_integer()]) :: map()
  defp return_copies(counts, item_ids) do
    Enum.reduce(item_ids, counts, &Map.update(&2, &1, 1, fn copies -> copies + 1 end))
  end
end
