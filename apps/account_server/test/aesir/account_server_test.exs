defmodule Aesir.AccountServerTest do
  use ExUnit.Case

  import Mimic

  alias Aesir.AccountServer
  alias Aesir.AccountServer.AccountManager
  alias Aesir.AccountServer.Packets.AcAcceptLogin
  alias Aesir.AccountServer.Packets.AcRefuseLogin
  alias Aesir.AccountServer.Packets.CaLogin

  setup :verify_on_exit!

  describe "handle_packet/3 with CaLogin" do
    setup do
      session = %{
        socket: :test_socket,
        username: nil,
        account_id: nil,
        auth_code: nil,
        login_id1: nil,
        login_id2: nil,
        authenticated: false
      }

      login_packet = %CaLogin{
        version: 20_120_716,
        username: "test",
        password: "test123",
        client_type: 0
      }

      %{session: session, login_packet: login_packet}
    end

    test "handles successful login", %{session: session, login_packet: login_packet} do
      account = %{
        id: 1,
        username: "test",
        level: 0,
        sex: "M",
        email: "test@example.com"
      }

      stub(AccountManager, :authenticate, fn "test", "test123" ->
        {:ok, account}
      end)

      {:ok, new_session, [response]} = AccountServer.handle_packet(0x0064, login_packet, session)

      assert %AcAcceptLogin{} = response
      assert response.aid == 1
      assert response.sex == :male
      assert response.token != nil
      assert response.last_ip == {127, 0, 0, 1}
      assert response.last_login != nil
      assert length(response.char_servers) == 1

      server = hd(response.char_servers)
      assert server.name == "Aesir"
      assert server.type == 0
      assert server.new? == false

      assert new_session.username == "test"
      assert new_session.account_id == 1
      assert new_session.authenticated == true
    end

    test "handles login with invalid password", %{session: session, login_packet: login_packet} do
      stub(AccountManager, :authenticate, fn "test", "test123" ->
        {:error, :invalid_password}
      end)

      {:ok, new_session, [response]} = AccountServer.handle_packet(0x0064, login_packet, session)

      assert %AcRefuseLogin{} = response
      assert response.reason_code == 1
      assert new_session == session
    end

    test "handles login with non-existent account", %{
      session: session,
      login_packet: login_packet
    } do
      stub(AccountManager, :authenticate, fn "test", "test123" ->
        {:error, :account_not_found}
      end)

      {:ok, new_session, [response]} = AccountServer.handle_packet(0x0064, login_packet, session)

      assert %AcRefuseLogin{} = response
      assert response.reason_code == 0
      assert new_session == session
    end

    test "handles login with banned account", %{session: session, login_packet: login_packet} do
      stub(AccountManager, :authenticate, fn "test", "test123" ->
        {:error, :banned}
      end)

      {:ok, new_session, [response]} = AccountServer.handle_packet(0x0064, login_packet, session)

      assert %AcRefuseLogin{} = response
      assert response.reason_code == 6
      assert new_session == session
    end

    test "handles server temporarily unavailable error", %{
      session: session,
      login_packet: login_packet
    } do
      stub(AccountManager, :authenticate, fn "test", "test123" ->
        {:error, :unknown_error}
      end)

      {:ok, new_session, [response]} = AccountServer.handle_packet(0x0064, login_packet, session)

      assert %AcRefuseLogin{} = response
      assert response.reason_code == 3
      assert new_session == session
    end

    test "generates different auth codes for each login", %{
      session: session,
      login_packet: login_packet
    } do
      account = %{
        id: 1,
        username: "test",
        level: 0,
        sex: "M",
        email: "test@example.com"
      }

      stub(AccountManager, :authenticate, fn "test", "test123" ->
        {:ok, account}
      end)

      {:ok, session1, [response1]} = AccountServer.handle_packet(0x0064, login_packet, session)
      {:ok, _session2, [response2]} = AccountServer.handle_packet(0x0064, login_packet, session)

      assert response1.login_id1 != response2.login_id1
      assert response1.login_id2 != response2.login_id2
      assert response1.token != response2.token
      assert session1.auth_code != nil
      assert session1.login_id1 != nil
      assert session1.login_id2 != nil
    end
  end

  describe "handle_packet/3 with unknown packet" do
    test "logs warning for unhandled packet" do
      session = %{socket: :test_socket}

      result = AccountServer.handle_packet(0xFFFF, %{}, session)

      assert {:ok, ^session} = result
    end
  end

  describe "integration scenarios" do
    test "multiple login attempts update session correctly" do
      session = %{
        socket: :test_socket,
        username: nil,
        account_id: nil,
        auth_code: nil,
        login_id1: nil,
        login_id2: nil,
        authenticated: false
      }

      stub(AccountManager, :authenticate, fn username, password ->
        case {username, password} do
          {"test", "wrong"} ->
            {:error, :invalid_password}

          {"test", "test123"} ->
            {:ok, %{id: 1, username: "test", level: 0, sex: "M", email: ""}}

          _ ->
            {:error, :account_not_found}
        end
      end)

      login_fail = %CaLogin{
        version: 20_120_716,
        username: "test",
        password: "wrong",
        client_type: 0
      }

      {:ok, session_after_fail, [fail_response]} =
        AccountServer.handle_packet(0x0064, login_fail, session)

      assert %AcRefuseLogin{} = fail_response
      assert session_after_fail.username == nil

      login_success = %CaLogin{
        version: 20_120_716,
        username: "test",
        password: "test123",
        client_type: 0
      }

      {:ok, session_after_success, [success_response]} =
        AccountServer.handle_packet(0x0064, login_success, session_after_fail)

      assert %AcAcceptLogin{} = success_response
      assert session_after_success.username == "test"
      assert session_after_success.account_id == 1
    end
  end
end
