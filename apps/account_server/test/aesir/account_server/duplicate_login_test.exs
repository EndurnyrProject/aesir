defmodule Aesir.AccountServer.DuplicateLoginTest do
  use ExUnit.Case, async: false
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.AccountServer
  alias Aesir.AccountServer.Packets.CaLogin
  alias Aesir.Commons.Auth
  alias Aesir.Commons.InterServer.PubSub
  alias Aesir.Commons.MementoTestHelper
  alias Aesir.Commons.SessionManager

  setup :set_mimic_global
  setup :verify_on_exit!

  setup do
    Mimic.copy(Auth)
    Mimic.copy(SessionManager)
    MementoTestHelper.reset_test_environment()
    PubSub.subscribe_to_player_events()

    :ok
  end

  describe "duplicate login prevention" do
    test "allows second login and kicks old session when user is already online" do
      account_id = 200
      username = "duplicate_user"

      account = %{
        id: account_id,
        userid: username,
        sex: "M",
        lastlogin: NaiveDateTime.utc_now()
      }

      session_data = %{
        login_id1: 1,
        login_id2: 2,
        auth_code: 1234,
        username: username
      }

      SessionManager.create_session(account_id, session_data)
      SessionManager.set_user_online(account_id, :account_server)

      stub(Auth, :authenticate_user, fn ^username, _password ->
        {:ok, account}
      end)

      stub(SessionManager, :get_servers, fn :char_server ->
        [
          %{
            server_id: "char-01",
            server_type: :char_server,
            status: :online,
            ip: {127, 0, 0, 1},
            port: 6121,
            player_count: 0,
            metadata: %{
              name: "Test Char Server",
              cluster_id: 0,
              type: 0,
              new: false
            }
          }
        ]
      end)

      login_packet = %CaLogin{
        username: username,
        password: "password123",
        client_type: 0
      }

      capture_log(fn ->
        {:ok, session_data, responses} =
          AccountServer.handle_packet(0x0064, login_packet, %{})

        assert session_data.account_id == account_id
        assert session_data.authenticated == true
        assert length(responses) == 1

        assert_received {:player_event, %{event: "kick_connection", account_id: ^account_id}}

        {:ok, online_user} = SessionManager.get_online_user(account_id)
        assert online_user.account_id == account_id
        assert online_user.username == username
        assert online_user.server_type == :account_server
      end)
    end

    test "allows login when user is not online" do
      account_id = 201
      username = "fresh_user"

      account = %{
        id: account_id,
        userid: username,
        sex: "F",
        lastlogin: NaiveDateTime.utc_now()
      }

      stub(Auth, :authenticate_user, fn ^username, _password ->
        {:ok, account}
      end)

      stub(SessionManager, :get_servers, fn :char_server ->
        [
          %{
            server_id: "char-01",
            server_type: :char_server,
            status: :online,
            ip: {127, 0, 0, 1},
            port: 6121,
            player_count: 0,
            metadata: %{
              name: "Test Char Server",
              cluster_id: 0,
              type: 0,
              new: false
            }
          }
        ]
      end)

      login_packet = %CaLogin{
        username: username,
        password: "password123",
        client_type: 0
      }

      capture_log(fn ->
        {:ok, session_data, responses} =
          AccountServer.handle_packet(0x0064, login_packet, %{})

        assert session_data.account_id == account_id
        assert session_data.authenticated == true
        assert length(responses) == 1

        {:ok, online_user} = SessionManager.get_online_user(account_id)
        assert online_user.account_id == account_id
        assert online_user.username == username
        assert online_user.server_type == :account_server
      end)
    end

    test "allows login after first connection is kicked" do
      account_id = 202
      username = "sequential_user"

      account = %{
        id: account_id,
        userid: username,
        sex: "M",
        lastlogin: NaiveDateTime.utc_now()
      }

      session_data = %{
        login_id1: 1,
        login_id2: 2,
        auth_code: 1234,
        username: username
      }

      SessionManager.create_session(account_id, session_data)
      SessionManager.set_user_online(account_id, :account_server)

      assert {:ok, _online_user} = SessionManager.get_online_user(account_id)

      SessionManager.end_session(account_id)

      assert {:error, :not_found} = SessionManager.get_online_user(account_id)

      stub(Auth, :authenticate_user, fn ^username, _password ->
        {:ok, account}
      end)

      stub(SessionManager, :get_servers, fn :char_server ->
        [
          %{
            server_id: "char-01",
            server_type: :char_server,
            status: :online,
            ip: {127, 0, 0, 1},
            port: 6121,
            player_count: 0,
            metadata: %{
              name: "Test Char Server",
              cluster_id: 0,
              type: 0,
              new: false
            }
          }
        ]
      end)

      login_packet = %CaLogin{
        username: username,
        password: "password123",
        client_type: 0
      }

      capture_log(fn ->
        {:ok, session_data, responses} =
          AccountServer.handle_packet(0x0064, login_packet, %{})

        assert session_data.account_id == account_id
        assert session_data.authenticated == true
        assert length(responses) == 1

        {:ok, online_user} = SessionManager.get_online_user(account_id)
        assert online_user.account_id == account_id
        assert online_user.username == username
      end)
    end
  end

  describe "kick connection handling" do
    test "connection receives kick event and should terminate" do
      account_id = 203

      state = %{
        session_data: %{account_id: account_id},
        socket: nil,
        transport: nil
      }

      event = %{
        event: "kick_connection",
        account_id: account_id,
        reason: :duplicate_login,
        node: Node.self(),
        timestamp: DateTime.utc_now()
      }

      result =
        Aesir.Commons.Network.Connection.handle_info({:player_event, event}, state)

      assert {:stop, :kicked, ^state} = result
    end

    test "connection ignores kick event for different account" do
      account_id = 204
      other_account_id = 999

      state = %{
        session_data: %{account_id: account_id},
        socket: nil,
        transport: nil
      }

      event = %{
        event: "kick_connection",
        account_id: other_account_id,
        reason: :duplicate_login,
        node: Node.self(),
        timestamp: DateTime.utc_now()
      }

      result =
        Aesir.Commons.Network.Connection.handle_info({:player_event, event}, state)

      assert {:noreply, ^state} = result
    end

    test "connection ignores kick event when no account_id in session" do
      other_account_id = 205

      state = %{
        session_data: %{},
        socket: nil,
        transport: nil
      }

      event = %{
        event: "kick_connection",
        account_id: other_account_id,
        reason: :duplicate_login,
        node: Node.self(),
        timestamp: DateTime.utc_now()
      }

      result =
        Aesir.Commons.Network.Connection.handle_info({:player_event, event}, state)

      assert {:noreply, ^state} = result
    end
  end
end
