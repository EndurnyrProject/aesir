defmodule Aesir.ZoneServer.Map.MapManager do
  @moduledoc """
  Manages the lifecycle of all map coordinators in the zone server.
  Responsible for starting coordinators for all available maps on system startup.
  """
  use GenServer

  require Logger

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.PartitionedSupervisor

  defstruct [
    :initialized,
    :coordinators,
    :failed_maps
  ]

  @doc """
  Starts the MapManager GenServer.
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the coordinator PID for a specific map.
  """
  @spec get_coordinator(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def get_coordinator(map_name) when is_binary(map_name) do
    GenServer.call(__MODULE__, {:get_coordinator, map_name})
  end

  @doc """
  Gets the status of all map coordinators.
  """
  @spec coordinator_status() :: %{
          initialized: boolean(),
          total_maps: non_neg_integer(),
          successful: non_neg_integer(),
          failed: non_neg_integer(),
          failed_maps: [String.t()]
        }
  def coordinator_status do
    GenServer.call(__MODULE__, :coordinator_status)
  end

  @doc """
  Restarts a failed map coordinator.
  """
  @spec restart_coordinator(String.t()) :: :ok | {:error, term()}
  def restart_coordinator(map_name) when is_binary(map_name) do
    GenServer.call(__MODULE__, {:restart_coordinator, map_name})
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    # Start coordinators after other systems are ready
    Process.send_after(self(), :initialize_all_maps, 500)

    {:ok,
     %__MODULE__{
       initialized: false,
       coordinators: %{},
       failed_maps: []
     }}
  end

  @impl true
  def handle_info(:initialize_all_maps, state) do
    Logger.info("Starting Map.Coordinators for all maps...")

    # Get all maps from cache
    all_maps = MapCache.list_maps()
    total = length(all_maps)

    Logger.info("Found #{total} maps in cache, starting coordinators...")

    # Start coordinator for every map
    {coordinators, failed_maps} =
      all_maps
      |> Enum.reduce({%{}, []}, fn map_name, {coords, failed} ->
        case start_coordinator_for_map(map_name) do
          {:ok, pid} ->
            {Map.put(coords, map_name, pid), failed}

          {:error, reason} ->
            Logger.error("Failed to start coordinator for #{map_name}: #{inspect(reason)}")
            {coords, [map_name | failed]}
        end
      end)

    successful = map_size(coordinators)
    failed_count = length(failed_maps)

    Logger.info(
      "Map initialization complete: #{successful}/#{total} coordinators started" <>
        if(failed_count > 0, do: " (#{failed_count} failed)", else: "")
    )

    {:noreply, %{state | initialized: true, coordinators: coordinators, failed_maps: failed_maps}}
  end

  @impl true
  def handle_call({:get_coordinator, map_name}, _from, state) do
    result =
      case Registry.lookup(Aesir.ZoneServer.MapRegistry, map_name) do
        [{pid, _}] -> {:ok, pid}
        [] -> {:error, :not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:coordinator_status, _from, state) do
    total_maps = MapCache.list_maps() |> length()

    status = %{
      initialized: state.initialized,
      total_maps: total_maps,
      successful: map_size(state.coordinators),
      failed: length(state.failed_maps),
      failed_maps: state.failed_maps
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call({:restart_coordinator, map_name}, _from, state) do
    result =
      case start_coordinator_for_map(map_name) do
        {:ok, pid} ->
          new_coordinators = Map.put(state.coordinators, map_name, pid)
          new_failed = List.delete(state.failed_maps, map_name)

          Logger.info("Successfully restarted coordinator for #{map_name}")

          {:reply, :ok, %{state | coordinators: new_coordinators, failed_maps: new_failed}}

        {:error, reason} = error ->
          Logger.error("Failed to restart coordinator for #{map_name}: #{inspect(reason)}")
          {:reply, error, state}
      end

    result
  end

  # Private Functions

  defp start_coordinator_for_map(map_name) do
    case PartitionedSupervisor.start_map_coordinator(map_name) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.warning("Coordinator already exists for map: #{map_name}")
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
