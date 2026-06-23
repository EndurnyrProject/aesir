defmodule Aesir.AccountServer do
  @moduledoc """
  QUIC connection handler for the Account (login) server.

  Implements the `Aesir.Commons.Network.QuicConnection` behaviour: handles the
  Control-channel handshake (`Hello`/`HelloAck`) and the protobuf login flow
  (`LoginRequest` -> `LoginResponse`/`LoginFailed`), reusing the existing auth
  and distributed-session machinery. This replaces the legacy RO binary packet
  path that ran over Ranch/TCP.
  """
  @behaviour Aesir.Commons.Network.QuicConnection

  require Logger

  alias Aesir.Commons.Auth
  alias Aesir.Commons.InterServer.PubSub
  alias Aesir.Commons.SessionManager
  alias Aesir.Net.CharServerInfo
  alias Aesir.Net.Hello
  alias Aesir.Net.HelloAck
  alias Aesir.Net.LoginFailed
  alias Aesir.Net.LoginRequest
  alias Aesir.Net.LoginResponse

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
        %LoginRequest{username: username, password: password},
        :control,
        session_data
      ) do
    Logger.debug("Login attempt for user: #{username}")

    case Auth.authenticate_user(username, password) do
      {:ok, account} -> handle_successful_login(account, session_data)
      {:error, reason} -> handle_failed_login(reason, session_data)
    end
  end

  def handle_message(message, channel, session_data) do
    Logger.warning("Unhandled #{inspect(message.__struct__)} on #{channel} channel")
    {:ok, session_data}
  end

  defp handle_successful_login(account, session_data) do
    case SessionManager.get_online_user(account.id) do
      {:ok, _online_user} ->
        Logger.warning(
          "Duplicate login for account #{account.id} (#{account.userid}). Kicking old session and proceeding."
        )

        PubSub.broadcast_kick_connection(account.id, :duplicate_login)
        proceed_with_login(account, session_data)

      {:error, :not_found} ->
        proceed_with_login(account, session_data)
    end
  end

  defp proceed_with_login(account, session_data) do
    auth_code = :rand.uniform(999_999_999)
    login_id1 = :rand.uniform(999_999_999)
    login_id2 = :rand.uniform(999_999_999)

    updated_session =
      Map.merge(session_data, %{
        account_id: account.id,
        username: account.userid,
        auth_code: auth_code,
        login_id1: login_id1,
        login_id2: login_id2,
        authenticated: true
      })

    session_for_cluster = %{
      login_id1: login_id1,
      login_id2: login_id2,
      auth_code: auth_code,
      username: account.userid
    }

    with :ok <- SessionManager.create_session(account.id, session_for_cluster),
         {:ok, char_servers} <- available_char_servers() do
      SessionManager.set_user_online(account.id, :account_server)
      PubSub.broadcast_player_login(account.id, account.userid)

      response = %LoginResponse{
        account_id: account.id,
        login_id1: login_id1,
        login_id2: login_id2,
        sex: sex_code(account.sex),
        auth_token: auth_token(),
        char_servers: char_servers
      }

      Logger.info("Login successful for account: #{account.userid} (ID: #{account.id})")
      {:ok, updated_session, [{:login_response, response}]}
    else
      {:error, :no_char_servers} ->
        Logger.error("Login failed: no character servers available")
        handle_failed_login(:no_char_servers, session_data)

      {:error, reason} ->
        Logger.error(
          "Failed to create cluster session for account #{account.id}: #{inspect(reason)}"
        )

        handle_failed_login(reason, session_data)
    end
  end

  defp handle_failed_login(reason, session_data) do
    Logger.info("Login failed: #{inspect(reason)}")
    response = %LoginFailed{reason_code: reason_code(reason), message: to_string(reason)}
    {:ok, session_data, [{:login_failed, response}]}
  end

  defp reason_code(:invalid_credentials), do: 1
  defp reason_code(:banned), do: 6
  defp reason_code(:account_not_found), do: 0
  defp reason_code(_), do: 3

  defp sex_code("M"), do: 0
  defp sex_code("F"), do: 1

  defp auth_token do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  defp available_char_servers do
    case SessionManager.get_servers(:char_server) do
      [] ->
        {:error, :no_char_servers}

      servers ->
        servers
        |> Enum.filter(&(&1.status == :online))
        |> Enum.group_by(& &1.metadata[:cluster_id])
        |> Enum.map(fn {_cluster_id, cluster_servers} ->
          best_server = Enum.min_by(cluster_servers, & &1.player_count)

          %CharServerInfo{
            name: best_server.metadata[:name],
            ip: ip_to_string(best_server.ip),
            port: best_server.port,
            user_count: best_server.player_count,
            server_type: Map.get(best_server.metadata, :type, 0),
            is_new: Map.get(best_server.metadata, :new, false)
          }
        end)
        |> case do
          [] -> {:error, :no_char_servers}
          char_servers -> {:ok, char_servers}
        end
    end
  end

  defp ip_to_string(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> List.to_string()
  defp ip_to_string(ip) when is_binary(ip), do: ip
end
