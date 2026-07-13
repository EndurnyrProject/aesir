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
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Starts the mob supervisor for a specific map.
  """
  @spec start_link(String.t()) :: Supervisor.on_start()
  def start_link(map_name) do
    DynamicSupervisor.start_link(__MODULE__, map_name, name: via_tuple(map_name))
  end

  @doc """
  Spawns a new mob session under supervision.

  Pass `awake: false` to start the mob dormant (no AI tick loop) when its map
  currently has no players; the coordinator wakes it on player arrival.
  """
  @spec spawn_mob(String.t(), MobState.t(), keyword()) :: {:ok, pid()} | {:error, term()}
  def spawn_mob(map_name, mob_state, opts \\ []) do
    child_spec = %{
      id: MobSession,
      start:
        {MobSession, :start_link, [%{state: mob_state, awake: Keyword.get(opts, :awake, true)}]},
      restart: :temporary,
      type: :worker
    }

    case DynamicSupervisor.start_child(via_tuple(map_name), child_spec) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, reason} = error ->
        Logger.error(
          "Failed to spawn mob #{mob_state.mob_data.name} (ID: #{mob_state.instance_id}): #{inspect(reason)}"
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
  Suspends the AI loop of every mob on a map (see `MobSession.sleep/1`).
  """
  @spec sleep_all_mobs(String.t()) :: :ok
  def sleep_all_mobs(map_name) do
    map_name
    |> get_mob_processes()
    |> Enum.each(&MobSession.sleep/1)
  end

  @doc """
  Resumes the AI loop of every mob on a map (see `MobSession.wake/1`).
  """
  @spec wake_all_mobs(String.t()) :: :ok
  def wake_all_mobs(map_name) do
    map_name
    |> get_mob_processes()
    |> Enum.each(&MobSession.wake/1)
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
  Kills every mob on `map_name` matching `filter` (rAthena `killmonster`):
  `:all` kills every script-summoned mob (a `respawn_time`-0 spawn ref), and a
  binary event label kills mobs summoned with that owner event. Matching mobs
  are removed without firing their death event or scheduling a respawn — the
  registry entry is cleared and the process terminated (its `terminate/2`
  drops the spatial index entry and notifies nearby players).

  Runs in the caller's process; a mob that dies concurrently is skipped.
  """
  @spec kill_by_event(String.t(), :all | String.t()) :: :ok
  def kill_by_event(map_name, filter) do
    map_name
    |> get_mob_processes()
    |> Enum.each(fn pid ->
      try do
        mob = MobSession.get_state(pid)

        if kill_match?(mob, filter) do
          UnitRegistry.unregister_unit(:mob, mob.instance_id)
          terminate_mob(map_name, pid)
        end
      catch
        :exit, _ -> :ok
      end
    end)

    :ok
  end

  # `:all` spares spawn-table mobs (rAthena `!md->spawn`), approximated by the
  # never-respawning ref a script summon carries.
  defp kill_match?(%MobState{spawn_ref: %{respawn_time: 0}}, :all), do: true
  defp kill_match?(%MobState{}, :all), do: false
  defp kill_match?(%MobState{owner_event: event}, event) when is_binary(event), do: true
  defp kill_match?(%MobState{}, _filter), do: false

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
  def init(_map_name) do
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
