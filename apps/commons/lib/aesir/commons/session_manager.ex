defmodule Aesir.Commons.SessionManager do
  @moduledoc """
  Functional facade over the Horde-backed coordination layer.

  Reads hit the local CRDT replica directly (`Horde.Registry.lookup/select`);
  writes are owned by `Cluster.Entry` processes so liveness == presence. Session
  reads briefly retry to ride out CRDT propagation during the login handoff.
  """
  require Logger

  alias Aesir.Commons.Cluster
  alias Aesir.Commons.Cluster.Entry
  alias Aesir.Commons.InterServer.Schemas.OnlineUser
  alias Aesir.Commons.InterServer.Schemas.ServerStatus
  alias Aesir.Commons.InterServer.Schemas.Session

  @session_ttl :timer.hours(1)
  @read_retries 10
  @read_interval_ms 50

  @spec create_session(non_neg_integer(), map()) :: :ok | {:error, term()}
  def create_session(account_id, session_data) do
    %{login_id1: l1, login_id2: l2, auth_code: ac, username: u} = session_data
    session = Session.new(account_id, l1, l2, ac, u)
    key = {:session, account_id}

    stop_entry(key)
    result = start_entry(key: key, value: session, ttl: @session_ttl)
    Logger.info("Created session for account #{account_id}")
    result
  end

  @spec validate_session(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          {:ok, Session.t()} | {:error, :session_not_found | :invalid_credentials}
  def validate_session(account_id, login_id1, login_id2) do
    with {:ok, session} <- read_session(account_id),
         true <- session.login_id1 == login_id1 and session.login_id2 == login_id2 do
      touch_session(account_id)
      Logger.debug("Validated session for account #{account_id}")
      {:ok, Session.update_activity(session)}
    else
      false -> {:error, :invalid_credentials}
      {:error, :not_found} -> {:error, :session_not_found}
    end
  end

  @spec get_session(non_neg_integer()) :: {:ok, Session.t()} | {:error, :not_found}
  def get_session(account_id), do: read_session(account_id)

  @spec end_session(non_neg_integer()) :: :ok
  def end_session(account_id) do
    stop_entry({:session, account_id})
    stop_entry({:online, account_id})
    Logger.info("Ended session for account #{account_id}")
    :ok
  end

  @doc """
  Marks an account online on `server_type`, recording presence in the cluster.

  The presence entry is owned by the CALLING process: it is removed automatically
  when that process (or its node) dies. Therefore this MUST be called from the
  player's long-lived serving process (the per-connection process), so that
  presence tracks connection liveness.
  """
  @spec set_user_online(non_neg_integer(), atom(), non_neg_integer() | nil, String.t() | nil) ::
          :ok | {:error, term()}
  def set_user_online(account_id, server_type, character_id \\ nil, map_name \\ nil) do
    case read_session(account_id) do
      {:ok, session} ->
        transition_session(account_id, server_type, character_id)
        value = OnlineUser.new(account_id, session.username, server_type, character_id, map_name)
        finish_set_user_online(account_id, server_type, value)

      {:error, :not_found} ->
        {:error, :session_not_found}
    end
  end

  defp finish_set_user_online(account_id, server_type, value) do
    case put_user_online(account_id, value) do
      :ok ->
        Logger.debug("Set user #{account_id} online on #{server_type}")
        :ok

      other ->
        other
    end
  end

  defp put_user_online(account_id, value) do
    key = {:online, account_id}
    stop_entry(key)
    start_entry(key: key, value: value, anchor: self())
  end

  @spec get_online_user(non_neg_integer()) :: {:ok, OnlineUser.t()} | {:error, :not_found}
  def get_online_user(account_id) do
    case Horde.Registry.lookup(Cluster.registry(), {:online, account_id}) do
      [{_pid, %OnlineUser{} = user}] -> {:ok, user}
      [] -> {:error, :not_found}
    end
  end

  @spec get_online_count(atom() | nil) :: non_neg_integer()
  def get_online_count(server_type \\ nil) do
    {:online, :_}
    |> select_values()
    |> filter_by(:server_type, server_type)
    |> length()
  end

  @doc """
  Updates the cluster-wide presence record with the character's current map.

  Only `map_name` is tracked cluster-wide now; the authoritative character
  position (x/y) lives in Postgres. The previous `CharacterLocation` x/y
  tracking was intentionally removed, so the coordinates are accepted for API
  compatibility but dropped.
  """
  @spec update_character_location(
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          {integer(), integer()}
        ) :: :ok
  def update_character_location(_char_id, account_id, map_name, {_x, _y}) do
    safe_update({:online, account_id}, &OnlineUser.put_map(&1, map_name))
    :ok
  end

  @spec register_server(
          String.t(),
          atom(),
          :inet.ip_address(),
          non_neg_integer(),
          non_neg_integer(),
          map()
        ) ::
          :ok | {:error, term()}
  def register_server(server_id, server_type, ip, port, max_players \\ 1000, metadata \\ %{}) do
    value = ServerStatus.new(server_id, server_type, ip, port, max_players, metadata)
    key = {:server, server_id}

    stop_entry(key)

    case start_entry(key: key, value: value) do
      :ok ->
        Logger.info("Registered server #{server_id} (#{server_type})")
        :ok

      other ->
        other
    end
  end

  @spec update_server_heartbeat(String.t(), non_neg_integer()) ::
          :ok | {:error, :server_not_found}
  def update_server_heartbeat(server_id, player_count) do
    case lookup_pid({:server, server_id}) do
      {:ok, pid} ->
        try do
          Entry.update(pid, &ServerStatus.put_player_count(&1, player_count))
          :ok
        catch
          :exit, _ -> :ok
        end

      :error ->
        {:error, :server_not_found}
    end
  end

  @spec unregister_server(String.t()) :: :ok
  def unregister_server(server_id) do
    stop_entry({:server, server_id})
    :ok
  end

  @spec get_servers(atom() | nil) :: [ServerStatus.t()]
  def get_servers(server_type \\ nil) do
    {:server, :_}
    |> select_values()
    |> filter_by(:server_type, server_type)
  end

  defp start_entry(opts, attempts \\ 5) do
    case DynamicSupervisor.start_child(Cluster.owner_supervisor(), {Entry, opts}) do
      {:ok, _pid} ->
        :ok

      :ignore when attempts > 0 ->
        Process.sleep(50)
        start_entry(opts, attempts - 1)

      :ignore ->
        {:error, :already_registered}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp stop_entry(key) do
    case lookup_pid(key) do
      {:ok, pid} ->
        try do
          GenServer.stop(pid, :normal, 1_000)
        catch
          :exit, _ -> :ok
        end

      :error ->
        :ok
    end
  end

  defp safe_update(key, fun) do
    case lookup_pid(key) do
      {:ok, pid} ->
        try do
          Entry.update(pid, fun)
          :ok
        catch
          :exit, _ -> :ok
        end

      :error ->
        :ok
    end
  end

  defp lookup_pid(key) do
    case Horde.Registry.lookup(Cluster.registry(), key) do
      [{pid, _value}] -> {:ok, pid}
      [] -> :error
    end
  end

  defp read_session(account_id), do: read_session(account_id, @read_retries)

  defp read_session(account_id, retries) do
    case Horde.Registry.lookup(Cluster.registry(), {:session, account_id}) do
      [{_pid, %Session{} = session}] ->
        {:ok, session}

      [] when retries > 0 ->
        Process.sleep(@read_interval_ms)
        read_session(account_id, retries - 1)

      [] ->
        {:error, :not_found}
    end
  end

  defp touch_session(account_id) do
    safe_update({:session, account_id}, &Session.update_activity/1)
  end

  defp transition_session(account_id, server_type, character_id) do
    fun =
      case server_type do
        :char_server -> &Session.transition_to_char_server/1
        :zone_server -> &Session.transition_to_game(&1, character_id)
        _ -> &Session.update_activity/1
      end

    safe_update({:session, account_id}, fun)
  end

  defp select_values({tag, :_}) do
    Horde.Registry.select(Cluster.registry(), [{{{tag, :_}, :_, :"$1"}, [], [:"$1"]}])
  end

  defp filter_by(values, _field, nil), do: values
  defp filter_by(values, field, value), do: Enum.filter(values, &(Map.get(&1, field) == value))
end
