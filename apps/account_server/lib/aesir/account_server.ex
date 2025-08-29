defmodule Aesir.AccountServer do
  @moduledoc """
  Connection handler for the Account Server.
  Processes login packets and manages authentication flow.
  """
  use Aesir.Commons.Network.Connection

  require Logger

  alias Aesir.AccountServer.Packets.AcAcceptLogin
  alias Aesir.AccountServer.Packets.AcRefuseLogin
  alias Aesir.AccountServer.Packets.CaLogin
  alias Aesir.AccountServer.Packets.CtAuth
  alias Aesir.AccountServer.Packets.TcResult
  alias Aesir.Commons.Auth
  alias Aesir.Commons.InterServer.PubSub
  alias Aesir.Commons.SessionManager

  @impl Aesir.Commons.Network.Connection
  def handle_packet(0x0ACF, %CtAuth{} = _auth_packet, session_data) do
    {:ok, session_data, [%TcResult{}]}
  end

  @impl Aesir.Commons.Network.Connection
  def handle_packet(0x0064, %CaLogin{} = login_packet, session_data) do
    Logger.info("Login attempt for user: #{login_packet.username}")

    case Auth.authenticate_user(login_packet.username, login_packet.password) do
      {:ok, account} ->
        handle_successful_login(account, session_data)

      {:error, reason} ->
        handle_failed_login(reason, session_data)
    end
  end

  def handle_packet(packet_id, _parsed_data, session_data) do
    Logger.warning("Unhandled packet in LoginConnection: 0x#{Integer.to_string(packet_id, 16)}")
    {:ok, session_data}
  end

  defp handle_successful_login(account, session_data) do
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

    session_data_for_cluster = %{
      login_id1: login_id1,
      login_id2: login_id2,
      auth_code: auth_code,
      username: account.userid
    }

    case SessionManager.create_session(account.id, session_data_for_cluster) do
      :ok ->
        Logger.info("Session created in cluster for account #{account.id}")
        SessionManager.set_user_online(account.id, :account_server)
        PubSub.broadcast_player_login(account.id, account.userid)

        sex_atom =
          case account.sex do
            "M" -> :male
            "F" -> :female
          end

        token =
          :crypto.strong_rand_bytes(16)
          |> Base.encode16(case: :lower)
          |> String.slice(0, 16)

        last_login =
          if account.lastlogin do
            NaiveDateTime.to_string(account.lastlogin)
          else
            NaiveDateTime.to_string(NaiveDateTime.utc_now())
          end

        case get_available_char_servers() do
          {:ok, char_servers} ->
            response =
              %AcAcceptLogin{
                login_id1: login_id1,
                aid: account.id,
                login_id2: login_id2,
                last_ip: {127, 0, 0, 1},
                last_login: last_login,
                sex: sex_atom,
                token: token,
                char_servers: char_servers
              }

            Logger.info("Login successful for account: #{account.userid} (ID: #{account.id})")

            {:ok, updated_session, [response]}

          {:error, reason} ->
            Logger.error("Login failed: no character servers available (#{reason})")
            handle_failed_login(:no_char_servers, session_data)
        end

      {:error, reason} ->
        Logger.error(
          "Failed to create cluster session for account #{account.id}: #{inspect(reason)}"
        )

        handle_failed_login(reason, session_data)
    end
  end

  defp handle_failed_login(reason, session_data) do
    reason_code =
      case reason do
        :invalid_credentials -> 1
        :banned -> 6
        :account_not_found -> 0
        _ -> 3
      end

    response = %AcRefuseLogin{
      reason_code: reason_code,
      block_date: ""
    }

    Logger.info("Login failed: #{reason}")
    {:ok, session_data, [response]}
  end

  defp get_available_char_servers do
    case SessionManager.get_servers(:char_server) do
      [] ->
        {:error, :no_char_servers}

      servers ->
        online_servers =
          servers
          |> Enum.filter(fn server -> server.status == :online end)
          |> Enum.group_by(fn server -> server.metadata[:cluster_id] end)
          |> Enum.map(fn {_cluster_id, cluster_servers} ->
            best_server = Enum.min_by(cluster_servers, & &1.player_count)

            %AcAcceptLogin.ServerInfo{
              ip: best_server.ip,
              port: best_server.port,
              name: best_server.metadata[:name],
              users: best_server.player_count,
              type: best_server.metadata[:type] || 0,
              new?: best_server.metadata[:new] || false
            }
          end)

        case online_servers do
          [] -> {:error, :no_online_char_servers}
          servers -> {:ok, servers}
        end
    end
  end
end
