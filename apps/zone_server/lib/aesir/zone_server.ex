defmodule Aesir.ZoneServer do
  @moduledoc """
    QUIC connection handler for the Zone Server (Map Server).

    Implements the `Aesir.Commons.Network.QuicConnection` behaviour: handles the
    Control-channel handshake (`Hello`/`HelloAck`), the entry/auth flow
    (`SessionAuth` -> load character -> start player -> `EnterAck`)
  """
  @behaviour Aesir.Commons.Network.QuicConnection

  require Logger

  alias Aesir.Commons.SessionManager
  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.EnterAck
  alias Aesir.Net.Hello
  alias Aesir.Net.HelloAck
  alias Aesir.Net.SessionAuth
  alias Aesir.Net.TimeSync
  alias Aesir.Net.TimeSyncAck
  alias Aesir.ZoneServer.CharacterLoader
  alias Aesir.ZoneServer.Unit.Player.PlayerSupervisor

  @protocol_version 1

  @impl true
  def handle_message(%Hello{protocol_version: version}, :control, session_data) do
    if version != @protocol_version do
      Logger.warning("Client protocol version #{version} does not match #{@protocol_version}")
    end

    response = %HelloAck{
      protocol_version: @protocol_version,
      accepted: version == @protocol_version
    }

    {:ok, session_data, [{:hello_ack, response}]}
  end

  def handle_message(
        %SessionAuth{account_id: account_id, login_id1: login_id1, char_id: char_id} = auth,
        :control,
        session_data
      ) do
    Logger.debug("Auth data: Account ID: #{account_id}, Char ID: #{char_id}")

    with {:ok, session} <- SessionManager.get_session(account_id),
         :ok <- validate_auth_code(session, login_id1),
         updated_session <- build_session_data(session_data, auth),
         {:ok, character} <- CharacterLoader.load_character(char_id, account_id),
         :ok <-
           SessionManager.set_user_online(
             account_id,
             :zone_server,
             char_id,
             "#{character.last_map}"
           ),
         {:ok, player_pid} <-
           PlayerSupervisor.start_player(%{character: character, connection_pid: self()}),
         final_session <- Map.put(updated_session, :player_session_pid, player_pid) do
      Logger.info("Started PlayerSession #{inspect(player_pid)} for char #{char_id}")

      enter_ack = %EnterAck{
        account_id: account_id,
        x: character.last_x,
        y: character.last_y,
        dir: 4,
        start_time: System.system_time(:millisecond),
        font: 0
      }

      {:ok, final_session, [{:enter_ack, enter_ack}]}
    else
      {:error, :session_not_found} = error ->
        Logger.warning("Session not found for account #{account_id}")
        error

      {:error, :invalid_auth} = error ->
        Logger.warning("Auth code mismatch for account #{account_id}")
        error

      {:error, :character_load_failed} = error ->
        Logger.error("Failed to load character #{char_id}")
        error

      {:error, reason} = error ->
        Logger.error("Failed to handle SessionAuth: #{inspect(reason)}")
        error
    end
  end

  def handle_message(%TimeSync{}, _channel, session_data) do
    {:ok, session_data, [{:time_sync_ack, %TimeSyncAck{server_tick: ServerTick.now()}}]}
  end

  def handle_message(message, _channel, session_data) do
    case get_player_session_pid(session_data) do
      {:ok, pid} ->
        send(pid, {:message, message})
        {:ok, session_data}

      :no_session ->
        Logger.warning(
          "Unhandled #{inspect(message.__struct__)} in ZoneServer (no player session)"
        )

        {:ok, session_data}
    end
  end

  defp validate_auth_code(session, login_id1) do
    if session.login_id1 == login_id1 do
      :ok
    else
      {:error, :invalid_auth}
    end
  end

  defp build_session_data(session_data, %SessionAuth{} = auth) do
    Map.merge(session_data, %{
      account_id: auth.account_id,
      char_id: auth.char_id,
      login_id1: auth.login_id1,
      login_id2: auth.login_id2,
      sex: auth.sex
    })
  end

  defp get_player_session_pid(session_data) do
    case Map.get(session_data, :player_session_pid) do
      pid when is_pid(pid) -> {:ok, pid}
      _ -> :no_session
    end
  end
end
