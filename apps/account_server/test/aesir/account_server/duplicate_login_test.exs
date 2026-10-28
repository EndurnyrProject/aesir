defmodule Aesir.AccountServer.DuplicateLoginTest do
  use ExUnit.Case, async: false
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.AccountServer
  alias Aesir.Commons.Auth
  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.InterServer.PubSub
  alias Aesir.Commons.Network.QuicConnection
  alias Aesir.Commons.SessionManager
  alias Aesir.Net.LoginFailed
  alias Aesir.Net.LoginRequest
  alias Aesir.Net.LoginResponse

  setup {Aesir.MimicMode, :global}
  setup :verify_on_exit!

  setup do
    ClusterTestHelper.clear_all()
    PubSub.subscribe_to_player_events()

    :ok
  end

  describe "duplicate login prevention" do
    test "replaces a session that only authed at the login server, without a kick" do
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

      login = %LoginRequest{
        username: username,
        password: "password123",
        client_version: 0
      }

      capture_log(fn ->
        {:ok, session_data, responses} =
          AccountServer.handle_message(login, :control, %{})

        assert session_data.account_id == account_id
        assert session_data.authenticated == true
        assert [{:login_response, %LoginResponse{account_id: ^account_id}}] = responses

        refute_received {:player_event, %{event: "kick_connection", account_id: ^account_id}}

        {:ok, online_user} = SessionManager.get_online_user(account_id)
        assert online_user.account_id == account_id
        assert online_user.username == username
        assert online_user.server_type == :account_server
      end)
    end

    test "refuses with code 8 and kicks an account on a char or zone server" do
      stub_char_servers()

      for {server_type, account_id} <- [char_server: 206, zone_server: 207] do
        username = "online_#{account_id}"
        stub_authenticated(username, account_id)

        SessionManager.create_session(account_id, %{
          login_id1: 1,
          login_id2: 2,
          auth_code: 1234,
          username: username
        })

        SessionManager.set_user_online(account_id, server_type)

        capture_log(fn ->
          assert {:ok, session, [{:login_failed, %LoginFailed{reason_code: 8}}]} =
                   AccountServer.handle_message(login_request(username), :control, %{})

          assert session == %{}
        end)

        assert_received {:player_event, %{event: "kick_connection", account_id: ^account_id}}
        assert {:ok, %{login_id1: 1, login_id2: 2}} = SessionManager.get_session(account_id)
        assert {:ok, %{server_type: ^server_type}} = SessionManager.get_online_user(account_id)
      end
    end

    test "reports no char server before an online account, without a kick" do
      account_id = 208
      username = "online_208"
      stub_authenticated(username, account_id)
      stub(SessionManager, :get_servers, fn :char_server -> [] end)

      SessionManager.create_session(account_id, %{
        login_id1: 1,
        login_id2: 2,
        auth_code: 1234,
        username: username
      })

      SessionManager.set_user_online(account_id, :char_server)

      capture_log(fn ->
        assert {:ok, session, [{:login_failed, %LoginFailed{reason_code: 3}}]} =
                 AccountServer.handle_message(login_request(username), :control, %{})

        assert session == %{}
      end)

      refute_received {:player_event, %{event: "kick_connection", account_id: ^account_id}}
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

      login = %LoginRequest{
        username: username,
        password: "password123",
        client_version: 0
      }

      capture_log(fn ->
        {:ok, session_data, responses} =
          AccountServer.handle_message(login, :control, %{})

        assert session_data.account_id == account_id
        assert session_data.authenticated == true
        assert [{:login_response, %LoginResponse{account_id: ^account_id}}] = responses

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

      login = %LoginRequest{
        username: username,
        password: "password123",
        client_version: 0
      }

      capture_log(fn ->
        {:ok, session_data, responses} =
          AccountServer.handle_message(login, :control, %{})

        assert session_data.account_id == account_id
        assert session_data.authenticated == true
        assert [{:login_response, %LoginResponse{account_id: ^account_id}}] = responses

        {:ok, online_user} = SessionManager.get_online_user(account_id)
        assert online_user.account_id == account_id
        assert online_user.username == username
      end)
    end
  end

  defp stub_authenticated(username, account_id) do
    account = %{id: account_id, userid: username, sex: "M", lastlogin: NaiveDateTime.utc_now()}
    stub(Auth, :authenticate_user, fn ^username, _password -> {:ok, account} end)
  end

  defp stub_char_servers do
    stub(SessionManager, :get_servers, fn :char_server ->
      [
        %{
          server_id: "char-01",
          server_type: :char_server,
          status: :online,
          ip: {127, 0, 0, 1},
          port: 6121,
          player_count: 0,
          metadata: %{name: "Test Char Server", cluster_id: 0, type: 0, new: false}
        }
      ]
    end)
  end

  defp login_request(username),
    do: %LoginRequest{username: username, password: "password123", client_version: 0}

  describe "kick connection handling" do
    test "connection receives kick event and should terminate" do
      account_id = 203

      state = %QuicConnection.State{
        conn: self(),
        impl_module: AccountServer,
        account_id: account_id
      }

      event = %{
        event: "kick_connection",
        account_id: account_id,
        reason: :duplicate_login,
        node: Node.self(),
        timestamp: DateTime.utc_now()
      }

      capture_log(fn ->
        assert {:stop, :kicked, ^state} =
                 QuicConnection.handle_info({:player_event, event}, state)
      end)
    end

    test "connection ignores kick event for different account" do
      account_id = 204
      other_account_id = 999

      state = %QuicConnection.State{
        conn: self(),
        impl_module: AccountServer,
        account_id: account_id
      }

      event = %{
        event: "kick_connection",
        account_id: other_account_id,
        reason: :duplicate_login,
        node: Node.self(),
        timestamp: DateTime.utc_now()
      }

      assert {:noreply, ^state} =
               QuicConnection.handle_info({:player_event, event}, state)
    end

    test "connection ignores kick event when no account_id is known" do
      other_account_id = 205

      state = %QuicConnection.State{
        conn: self(),
        impl_module: AccountServer,
        account_id: nil
      }

      event = %{
        event: "kick_connection",
        account_id: other_account_id,
        reason: :duplicate_login,
        node: Node.self(),
        timestamp: DateTime.utc_now()
      }

      assert {:noreply, ^state} =
               QuicConnection.handle_info({:player_event, event}, state)
    end
  end
end
