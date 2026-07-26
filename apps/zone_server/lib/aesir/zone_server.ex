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
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSupervisor

  @protocol_version 1
  @supported_capabilities [:FEATURE_CAPABILITY_SKILL_TEXT_INPUT]

  @impl true
  def handle_message(
        %Hello{protocol_version: version, capabilities: capabilities},
        :control,
        session_data
      ) do
    if version != @protocol_version do
      Logger.warning("Client protocol version #{version} does not match #{@protocol_version}")
    end

    negotiated_capabilities =
      if version == @protocol_version do
        capabilities
        |> Enum.filter(&(&1 in @supported_capabilities))
        |> Enum.uniq()
      else
        []
      end

    response = %HelloAck{
      protocol_version: @protocol_version,
      accepted: version == @protocol_version,
      capabilities: negotiated_capabilities
    }

    {:ok, Map.put(session_data, :client_capabilities, negotiated_capabilities),
     [{:hello_ack, response}]}
  end

  def handle_message(
        %SessionAuth{
          account_id: account_id,
          login_id1: login_id1,
          login_id2: login_id2,
          char_id: char_id
        } = auth,
        :control,
        session_data
      ) do
    with {:ok, _session} <- SessionManager.validate_session(account_id, login_id1, login_id2),
         :ok <- verify_zone_token(account_id, char_id, auth.zone_auth_token),
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
           PlayerSupervisor.start_player(%{
             character: character,
             connection_pid: self(),
             client_capabilities: Map.get(updated_session, :client_capabilities, [])
           }),
         final_session <- Map.put(updated_session, :player_session_pid, player_pid) do
      Logger.debug("Started PlayerSession #{inspect(player_pid)} for char #{char_id}")

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

      {:error, :invalid_credentials} = error ->
        Logger.warning("Session credentials mismatch for account #{account_id}")
        error

      {:error, :invalid_zone_token} = error ->
        Logger.warning("Invalid zone auth token for account #{account_id} (char #{char_id})")
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
    forward_to_player_session(message, session_data)
  end

  defp forward_to_player_session(message, session_data) do
    case get_player_session_pid(session_data) do
      {:ok, pid} ->
        PlayerSession.deliver_message(pid, message)
        {:ok, session_data}

      :no_session ->
        Logger.warning(
          "Unhandled #{inspect(message.__struct__)} in ZoneServer (no player session)"
        )

        {:ok, session_data}
    end
  end

  defp verify_zone_token(account_id, char_id, token) do
    case SessionManager.consume_zone_token(account_id, char_id, token) do
      :ok ->
        :ok

      {:error, reason} ->
        if enforce_zone_token?() do
          {:error, :invalid_zone_token}
        else
          Logger.warning(
            "Zone auth token #{reason} for account #{account_id} (char #{char_id}); allowing because enforcement is disabled"
          )

          :ok
        end
    end
  end

  defp enforce_zone_token?, do: Application.get_env(:zone_server, :enforce_zone_auth_token, true)

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
