defmodule Aesir.AccountServer do
  @moduledoc """
  Connection handler for the Account Server.
  Processes login packets and manages authentication flow.
  """
  use Aesir.Network.Connection

  require Logger

  alias Aesir.AccountServer.AccountManager
  alias Aesir.AccountServer.Packets.AcAcceptLogin
  alias Aesir.AccountServer.Packets.AcRefuseLogin
  alias Aesir.AccountServer.Packets.CaLogin
  alias Aesir.AccountServer.Packets.CtAuth
  alias Aesir.AccountServer.Packets.TcResult

  @impl Aesir.Network.Connection
  def handle_packet(0x0ACF, %CtAuth{} = _auth_packet, session_data) do
    {:ok, session_data, [%TcResult{}]}
  end

  @impl Aesir.Network.Connection
  def handle_packet(0x0064, %CaLogin{} = login_packet, session_data) do
    Logger.info("Login attempt for user: #{login_packet.username}")

    case AccountManager.authenticate(login_packet.username, login_packet.password) do
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
        username: account.username,
        auth_code: auth_code,
        login_id1: login_id1,
        login_id2: login_id2,
        authenticated: true
      })

    sex_atom =
      case account.sex do
        "M" -> :male
        "F" -> :female
        _ -> :server
      end

    token =
      :crypto.strong_rand_bytes(16)
      |> Base.encode16(case: :lower)
      |> String.slice(0, 16)

    last_login = DateTime.to_string(DateTime.utc_now())

    response = %AcAcceptLogin{
      login_id1: login_id1,
      aid: account.id,
      login_id2: login_id2,
      last_ip: {127, 0, 0, 1},
      last_login: last_login,
      sex: sex_atom,
      token: token,
      char_servers: [
        %AcAcceptLogin.ServerInfo{
          ip: {127, 0, 0, 1},
          port: 6121,
          name: "Aesir",
          users: 42,
          type: 0,
          new?: false
        }
      ]
    }

    Logger.info("Login successful for account: #{account.username} (ID: #{account.id})")
    {:ok, updated_session, [response]}
  end

  defp handle_failed_login(reason, session_data) do
    reason_code =
      case reason do
        :invalid_password -> 1
        :banned -> 6
        :account_not_found -> 0
        _ -> 3
      end

    response = %AcRefuseLogin{
      reason_code: reason_code,
      block_date: ""
    }

    {:ok, session_data, [response]}
  end
end
