defmodule Aesir.ZoneServer.Unit.Mob.MobSupervisor do
  @moduledoc """
  Dynamic supervisor for managing mob session processes.

  Each map has its own MobSupervisor instance that manages all mobs on that map.
  This provides fault tolerance and automatic restart capabilities for mob processes.
  """

  use DynamicSupervisor
  require Logger

  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @doc """
  Starts the mob supervisor for a specific map.
  """
  @spec start_link(String.t()) :: Supervisor.on_start()
  def start_link(map_name) do
    DynamicSupervisor.start_link(__MODULE__, map_name, name: via_tuple(map_name))
  end

  @doc """
  Spawns a new mob session under supervision.
  """
  @spec spawn_mob(String.t(), MobState.t()) :: {:ok, pid()} | {:error, term()}
  def spawn_mob(map_name, mob_state) do
    child_spec = %{
      id: MobSession,
      start: {MobSession, :start_link, [%{state: mob_state}]},
      restart: :temporary,
      type: :worker
    }

    case DynamicSupervisor.start_child(via_tuple(map_name), child_spec) do
      {:ok, pid} ->
        Logger.debug(
          "Spawned mob #{mob_state.mob_data.sprite_name} (ID: #{mob_state.instance_id}) on #{map_name}"
        )

        {:ok, pid}

      {:error, reason} = error ->
        Logger.error(
          "Failed to spawn mob #{mob_state.mob_data.sprite_name} (ID: #{mob_state.instance_id}): #{inspect(reason)}"
        )

        error
    end
  end

  @doc """
  Terminates a mob session.
  """
  @spec terminate_mob(String.t(), pid()) :: :ok | {:error, :not_found}
  def terminate_mob(map_name, pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(via_tuple(map_name), pid)
  end

  @doc """
  Gets all running mob processes for a map.
  """
  @spec get_mob_processes(String.t()) :: [pid()]
  def get_mob_processes(map_name) do
    DynamicSupervisor.which_children(via_tuple(map_name))
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.filter(&is_pid/1)
  end

  @doc """
  Gets count of active mobs on a map.
  """
  @spec count_mobs(String.t()) :: integer()
  def count_mobs(map_name) do
    DynamicSupervisor.count_children(via_tuple(map_name)).active
  end

  @doc """
  Terminates all mob processes on a map.
  """
  @spec terminate_all_mobs(String.t()) :: :ok
  def terminate_all_mobs(map_name) do
    get_mob_processes(map_name)
    |> Enum.each(fn pid ->
      DynamicSupervisor.terminate_child(via_tuple(map_name), pid)
    end)

    Logger.info("Terminated all mobs on #{map_name}")
    :ok
  end

  @doc """
  Gets supervisor info for debugging.
  """
  @spec get_supervisor_info(String.t()) :: map()
  def get_supervisor_info(map_name) do
    children = DynamicSupervisor.count_children(via_tuple(map_name))

    %{
      map_name: map_name,
      active_mobs: children.active,
      supervisor_pid: GenServer.whereis(via_tuple(map_name)),
      processes: get_mob_processes(map_name)
    }
  end

  # GenServer Callbacks

  @impl DynamicSupervisor
  def init(map_name) do
    Logger.info("Started mob supervisor for map: #{map_name}")

    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 5,
      max_seconds: 60
    )
  end

  # Private Functions

  defp via_tuple(map_name) do
    {:via, Registry, {Aesir.ZoneServer.ProcessRegistry, {:mob_supervisor, map_name}}}
  end
end
