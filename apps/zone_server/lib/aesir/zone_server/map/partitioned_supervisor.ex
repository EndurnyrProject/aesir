defmodule Aesir.ZoneServer.Map.PartitionedSupervisor do
  @moduledoc """
  Module to manage partitioned supervisors for Map.Coordinator processes.
  Distributes map coordinators across CPU cores for optimal performance and fault isolation.
  """

  require Logger

  @doc """
  Returns the child specification for the PartitionSupervisor.
  """
  @spec child_spec(Keyword.t()) :: Supervisor.child_spec()
  def child_spec(_opts) do
    partitions = System.schedulers_online()

    Logger.info("Configuring Map.PartitionedSupervisor with #{partitions} partitions")

    %{
      id: __MODULE__,
      start:
        {PartitionSupervisor, :start_link,
         [
           [
             child_spec: DynamicSupervisor,
             name: __MODULE__,
             partitions: partitions
           ]
         ]},
      type: :supervisor
    }
  end

  @doc """
  Starts a map coordinator for the given map name.
  The coordinator will be assigned to a partition based on the map name hash.
  """
  @spec start_map_coordinator(String.t()) :: DynamicSupervisor.on_start_child()
  def start_map_coordinator(map_name) when is_binary(map_name) do
    partition = :erlang.phash2(map_name, System.schedulers_online())

    DynamicSupervisor.start_child(
      {:via, PartitionSupervisor, {__MODULE__, partition}},
      {Aesir.ZoneServer.Map.Coordinator, map_name: map_name}
    )
  end

  @doc """
  Stops a map coordinator for the given map name.
  """
  @spec stop_map_coordinator(String.t()) :: :ok | {:error, :not_found}
  def stop_map_coordinator(map_name) when is_binary(map_name) do
    case Registry.lookup(Aesir.ZoneServer.MapRegistry, map_name) do
      [{pid, _}] ->
        partition = :erlang.phash2(map_name, System.schedulers_online())

        DynamicSupervisor.terminate_child(
          {:via, PartitionSupervisor, {__MODULE__, partition}},
          pid
        )

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns the number of coordinators in each partition.
  Useful for monitoring load distribution.
  """
  @spec partition_distribution() :: %{non_neg_integer() => non_neg_integer()}
  def partition_distribution do
    partitions = System.schedulers_online()

    0..(partitions - 1)
    |> Enum.map(fn partition ->
      children =
        DynamicSupervisor.which_children({:via, PartitionSupervisor, {__MODULE__, partition}})

      {partition, length(children)}
    end)
    |> Map.new()
  end

  @doc """
  Returns the total number of map coordinators across all partitions.
  """
  @spec coordinator_count() :: non_neg_integer()
  def coordinator_count do
    partition_distribution()
    |> Map.values()
    |> Enum.sum()
  end
end
