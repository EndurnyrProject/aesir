defmodule Aesir.Commons.SessionManager do
  @moduledoc """
  GenServer-based session manager for distributed player sessions.
  Uses Memento for distributed state management across the cluster.
  """
  use GenServer

  require Logger

  alias Aesir.Commons.InterServer.Schemas.CharacterLocation
  alias Aesir.Commons.InterServer.Schemas.OnlineUser
  alias Aesir.Commons.InterServer.Schemas.ServerStatus
  alias Aesir.Commons.InterServer.Schemas.Session

  @server_name __MODULE__

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @server_name)
  end

  @doc """
  Create a new session for a player after successful login.
  """
  def create_session(account_id, session_data) do
    GenServer.call(@server_name, {:create_session, account_id, session_data})
  end

  @doc """
  Validate an existing session using login credentials.
  """
  def validate_session(account_id, login_id1, login_id2) do
    GenServer.call(@server_name, {:validate_session, account_id, login_id1, login_id2})
  end

  @doc """
  Update character location in the cluster.
  """
  def update_character_location(char_id, account_id, map_name, {x, y}) do
    GenServer.call(
      @server_name,
      {:update_character_location, char_id, account_id, map_name, x, y}
    )
  end

  @doc """
  Mark a user as online on a specific server type.
  """
  def set_user_online(account_id, server_type, character_id \\ nil, map_name \\ nil) do
    GenServer.call(
      @server_name,
      {:set_user_online, account_id, server_type, character_id, map_name}
    )
  end

  @doc """
  End a session and clean up associated data.
  """
  def end_session(account_id) do
    GenServer.call(@server_name, {:end_session, account_id})
  end

  @doc """
  Get session information for an account.
  """
  def get_session(account_id) do
    GenServer.call(@server_name, {:get_session, account_id})
  end

  @doc """
  Get online users count by server type.
  """
  def get_online_count(server_type \\ nil) do
    GenServer.call(@server_name, {:get_online_count, server_type})
  end

  @doc """
  Register a server in the cluster.
  """
  def register_server(server_id, server_type, ip, port, max_players \\ 1000, metadata \\ %{}) do
    GenServer.call(
      @server_name,
      {:register_server, server_id, server_type, ip, port, max_players, metadata}
    )
  end

  @doc """
  Update server heartbeat and player count.
  """
  def update_server_heartbeat(server_id, player_count) do
    GenServer.call(@server_name, {:update_server_heartbeat, server_id, player_count})
  end

  @doc """
  Get available servers by type.
  """
  def get_servers(server_type \\ nil) do
    GenServer.call(@server_name, {:get_servers, server_type})
  end

  @doc """
  Unregister a server from the cluster (marks as offline).
  """
  def unregister_server(server_id) do
    GenServer.call(@server_name, {:unregister_server, server_id})
  end

  # Server Callbacks
  #

  @impl true
  def init(init_arg) do
    schedule_cleanup()
    schedule_heartbeat()
    schedule_dead_node_cleanup()
    {:ok, init_arg}
  end

  @impl true
  def handle_call({:create_session, account_id, session_data}, _from, state) do
    %{
      login_id1: login_id1,
      login_id2: login_id2,
      auth_code: auth_code,
      username: username
    } = session_data

    session = Session.new(account_id, login_id1, login_id2, auth_code, username)

    case Memento.transaction(fn ->
           Memento.Query.write(session)
         end) do
      {:ok, _} ->
        Logger.info("Created session for account #{account_id}")
        {:reply, :ok, state}

      {:error, reason} ->
        Logger.error("Failed to create session for account #{account_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:validate_session, account_id, login_id1, login_id2}, _from, state) do
    result =
      Memento.transaction(fn ->
        case Memento.Query.read(Session, account_id) do
          nil ->
            {:error, :session_not_found}

          session ->
            if session.login_id1 == login_id1 and session.login_id2 == login_id2 do
              updated_session = Session.update_activity(session)
              Memento.Query.write(updated_session)
              {:ok, updated_session}
            else
              {:error, :invalid_credentials}
            end
        end
      end)

    case result do
      {:ok, {:ok, session}} ->
        Logger.info("Validated session for account #{account_id}")
        {:reply, {:ok, session}, state}

      {:ok, {:error, reason}} ->
        Logger.warning("Session validation failed for account #{account_id}: #{reason}")
        {:reply, {:error, reason}, state}

      {:error, reason} ->
        Logger.error("Session validation error for account #{account_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:update_character_location, char_id, account_id, map_name, x, y}, _from, state) do
    char_location = CharacterLocation.new(char_id, account_id, map_name, x, y, Node.self())

    case Memento.transaction(fn ->
           Memento.Query.write(char_location)
         end) do
      {:ok, _} ->
        Logger.debug("Updated character location for char #{char_id}")
        {:reply, :ok, state}

      {:error, reason} ->
        Logger.error(
          "Failed to update character location for char #{char_id}: #{inspect(reason)}"
        )

        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(
        {:set_user_online, account_id, server_type, character_id, map_name},
        _from,
        state
      ) do
    result =
      Memento.transaction(fn ->
        session = Memento.Query.read(Session, account_id)

        if session do
          updated_session =
            case server_type do
              :char_server -> Session.transition_to_char_server(session)
              :zone_server -> Session.transition_to_game(session, character_id)
              _ -> Session.update_activity(session)
            end

          Memento.Query.write(updated_session)

          online_user =
            OnlineUser.new(account_id, session.username, server_type, character_id, map_name)

          Memento.Query.write(online_user)

          :ok
        else
          {:error, :session_not_found}
        end
      end)

    case result do
      {:ok, :ok} ->
        Logger.info("Set user #{account_id} online on #{server_type}")
        {:reply, :ok, state}

      {:ok, {:error, reason}} ->
        Logger.warning("Failed to set user online: #{reason}")
        {:reply, {:error, reason}, state}

      :ok ->
        Logger.info("Set user #{account_id} online on #{server_type}")
        {:reply, :ok, state}

      {:error, reason} ->
        Logger.error("Failed to set user online: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:end_session, account_id}, _from, state) do
    result =
      Memento.transaction(fn ->
        Memento.Query.delete(Session, account_id)
        Memento.Query.delete(OnlineUser, account_id)

        :ok
      end)

    case result do
      {:ok, :ok} ->
        Logger.info("Ended session for account #{account_id}")
        {:reply, :ok, state}

      :ok ->
        Logger.info("Ended session for account #{account_id}")
        {:reply, :ok, state}

      {:error, reason} ->
        Logger.error("Failed to end session for account #{account_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_session, account_id}, _from, state) do
    case Memento.transaction(fn ->
           Memento.Query.read(Session, account_id)
         end) do
      {:ok, session} when session != nil ->
        {:reply, {:ok, session}, state}

      {:ok, nil} ->
        {:reply, {:error, :not_found}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_online_count, server_type}, _from, state) do
    count =
      case Memento.transaction(fn ->
             guards = if server_type, do: [{:==, :server_type, server_type}], else: []
             Memento.Query.select(OnlineUser, guards)
           end) do
        {:ok, users} -> length(users)
        {:error, _} -> 0
      end

    {:reply, count, state}
  end

  @impl true
  def handle_call(
        {:register_server, server_id, server_type, ip, port, max_players, metadata},
        _from,
        state
      ) do
    server_status = ServerStatus.new(server_id, server_type, ip, port, max_players, metadata)

    case Memento.transaction(fn ->
           Memento.Query.write(server_status)
         end) do
      {:ok, _} ->
        Logger.info("Registered server #{server_id} (#{server_type})")
        {:reply, :ok, state}

      {:error, reason} ->
        Logger.error("Failed to register server #{server_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:update_server_heartbeat, server_id, player_count}, _from, state) do
    result =
      Memento.transaction(fn ->
        case Memento.Query.read(ServerStatus, server_id) do
          nil ->
            {:error, :server_not_found}

          server_status ->
            updated_status = ServerStatus.update_heartbeat(server_status, player_count)
            Memento.Query.write(updated_status)
            :ok
        end
      end)

    case result do
      {:ok, :ok} ->
        {:reply, :ok, state}

      {:ok, {:error, reason}} ->
        {:reply, {:error, reason}, state}

      :ok ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_servers, server_type}, _from, state) do
    servers =
      case Memento.transaction(fn ->
             guards = if server_type, do: [{:==, :server_type, server_type}], else: []
             Memento.Query.select(ServerStatus, guards)
           end) do
        {:ok, servers} -> servers
        {:error, _} -> []
      end

    {:reply, servers, state}
  end

  @impl true
  def handle_call({:unregister_server, server_id}, _from, state) do
    result =
      Memento.transaction(fn ->
        case Memento.Query.read(ServerStatus, server_id) do
          nil ->
            {:error, :server_not_found}

          server_status ->
            Memento.Query.delete(ServerStatus, server_id)
            Logger.info("Deleted server #{server_id} on node #{server_status.server_node}")
            :ok
        end
      end)

    case result do
      {:ok, :ok} ->
        {:reply, :ok, state}

      {:ok, {:error, reason}} ->
        {:reply, {:error, reason}, state}

      :ok ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:cleanup_expired_sessions, state) do
    cleanup_expired_sessions()
    schedule_cleanup()
    {:noreply, state}
  end

  @impl true
  def handle_info(:send_heartbeat, state) do
    send_heartbeat()
    schedule_heartbeat()
    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup_dead_nodes, state) do
    cleanup_dead_nodes()
    schedule_dead_node_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired_sessions, 5 * 60 * 1000)
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :send_heartbeat, 10 * 1000)
  end

  defp schedule_dead_node_cleanup do
    Process.send_after(self(), :cleanup_dead_nodes, 15 * 1000)
  end

  defp cleanup_expired_sessions do
    one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)

    Memento.transaction(fn ->
      expired_sessions =
        Memento.Query.select(Session, [
          {:<, :last_activity, one_hour_ago}
        ])

      Enum.each(expired_sessions, fn session ->
        Memento.Query.delete(Session, session.account_id)
        Memento.Query.delete(OnlineUser, session.account_id)
        Logger.info("Cleaned up expired session for account #{session.account_id}")
      end)
    end)
  end

  defp send_heartbeat do
    current_node = Node.self()

    result =
      Memento.transaction(fn ->
        servers = Memento.Query.select(ServerStatus, [{:==, :server_node, current_node}])

        Enum.each(servers, fn server ->
          updated_server = ServerStatus.update_heartbeat(server)
          Memento.Query.write(updated_server)
          Logger.debug("Updated heartbeat for server #{server.server_id} on node #{current_node}")
        end)
      end)

    case result do
      :ok ->
        :ok

      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to send heartbeat: #{inspect(reason)}")
    end
  end

  defp cleanup_dead_nodes do
    timeout_seconds = 30
    now = DateTime.utc_now()

    result =
      Memento.transaction(fn ->
        all_servers = Memento.Query.select(ServerStatus, [])

        dead_servers =
          Enum.filter(all_servers, fn server ->
            DateTime.diff(now, server.last_heartbeat) > timeout_seconds &&
              server.status == :online
          end)

        Enum.each(dead_servers, fn server ->
          Logger.warning(
            "Deleting dead server #{server.server_id} on node #{server.server_node} (no heartbeat for #{DateTime.diff(now, server.last_heartbeat)} seconds)"
          )

          Memento.Query.delete(ServerStatus, server.server_id)

          cleanup_node_data(server.server_node)
        end)

        :ok
      end)

    case result do
      {:ok, :ok} ->
        :ok

      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to cleanup dead nodes: #{inspect(reason)}")
    end
  end

  defp cleanup_node_data(dead_node) do
    Logger.info("Cleaning up data for dead node: #{dead_node}")

    online_users = Memento.Query.select(OnlineUser, [{:==, :server_node, dead_node}])

    Enum.each(online_users, fn user ->
      Memento.Query.delete(OnlineUser, user.account_id)
      Logger.debug("Removed online user #{user.username} from dead node #{dead_node}")
    end)

    sessions = Memento.Query.select(Session, [{:==, :node, dead_node}])

    Enum.each(sessions, fn session ->
      Memento.Query.delete(Session, session.account_id)

      Logger.debug(
        "Removed session for account #{session.account_id} from dead node #{dead_node}"
      )
    end)

    char_locations = Memento.Query.select(CharacterLocation, [{:==, :node, dead_node}])

    Enum.each(char_locations, fn location ->
      Memento.Query.delete(CharacterLocation, location.char_id)

      Logger.debug(
        "Removed character location for char #{location.char_id} from dead node #{dead_node}"
      )
    end)

    Logger.info("Completed cleanup for dead node: #{dead_node}")
  end
end
