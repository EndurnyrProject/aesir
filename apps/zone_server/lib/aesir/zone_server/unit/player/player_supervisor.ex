defmodule Aesir.ZoneServer.Unit.Player.PlayerSupervisor do
  @moduledoc """
  DynamicSupervisor for managing player session processes.
  Each player gets their own supervised process for fault isolation.
  """
  use DynamicSupervisor

  require Logger

  alias Aesir.ZoneServer.Unit.UnitRegistry

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 3,
      max_seconds: 5
    )
  end

  @doc """
  Starts a new player session process.
  """
  def start_player(args) do
    character = args[:character] || args["character"]
    connection_pid = args[:connection_pid] || args["connection_pid"]

    child_spec = {
      Aesir.ZoneServer.Unit.Player.PlayerSession,
      [character: character, connection_pid: connection_pid]
    }

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        Logger.info(
          "Started player session for #{character.name} (#{character.id}) with PID #{inspect(pid)}"
        )

        {:ok, pid}

      {:error, reason} = error ->
        Logger.error("Failed to start player session for #{character.id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Stops a player session.
  """
  def stop_player(char_id) do
    case UnitRegistry.get_player_pid(char_id) do
      {:ok, pid} ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
        # UnitRegistry cleanup is handled by PlayerSession's terminate callback
        Logger.info("Stopped player session for char_id #{char_id}")
        :ok

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Gets a player session PID by character ID.
  """
  def get_player_pid(char_id) do
    UnitRegistry.get_player_pid(char_id)
  end

  @doc """
  Lists all active player sessions.
  """
  def list_players do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> pid end)
  end

  @doc """
  Gets count of active players.
  """
  def player_count, do: DynamicSupervisor.count_children(__MODULE__).active
end
