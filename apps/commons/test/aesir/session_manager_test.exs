defmodule Aesir.Commons.SessionManagerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.Commons.InterServer.Schemas.CharacterLocation
  alias Aesir.Commons.InterServer.Schemas.OnlineUser
  alias Aesir.Commons.InterServer.Schemas.ServerStatus
  alias Aesir.Commons.InterServer.Schemas.Session
  alias Aesir.Commons.SessionManager
  alias Aesir.Commons.MementoTestHelper

  setup do
    # Clear all tables for clean test state
    MementoTestHelper.reset_test_environment()
    :ok
  end

  describe "create_session/2" do
    test "successfully creates a new session" do
      account_id = 101

      session_data = %{
        login_id1: 1,
        login_id2: 2,
        auth_code: 1234,
        username: "testuser"
      }

      assert :ok = SessionManager.create_session(account_id, session_data)

      {:ok, session} = SessionManager.get_session(account_id)
      assert session.account_id == account_id
      assert session.username == "testuser"
      assert session.state == :authenticating
      assert session.current_server == :account_server
      assert session.login_id1 == 1
      assert session.login_id2 == 2
      assert session.auth_code == 1234
    end

    test "creates session with proper timestamps" do
      account_id = 102

      session_data = %{
        login_id1: 1,
        login_id2: 2,
        auth_code: 1234,
        username: "timeuser"
      }

      before_create = DateTime.utc_now()
      assert :ok = SessionManager.create_session(account_id, session_data)
      after_create = DateTime.utc_now()

      {:ok, session} = SessionManager.get_session(account_id)
      assert DateTime.compare(session.created_at, before_create) in [:gt, :eq]
      assert DateTime.compare(session.created_at, after_create) in [:lt, :eq]
      assert session.created_at == session.last_activity
    end
  end

  describe "validate_session/3" do
    test "successfully validates existing session with correct credentials" do
      account_id = 103
      login_id1 = 1
      login_id2 = 2
      username = "validuser"

      session_data = %{
        login_id1: login_id1,
        login_id2: login_id2,
        auth_code: 1234,
        username: username
      }

      assert :ok = SessionManager.create_session(account_id, session_data)

      {:ok, original_session} = SessionManager.get_session(account_id)
      original_activity = original_session.last_activity

      :timer.sleep(1)

      {:ok, validated_session} = SessionManager.validate_session(account_id, login_id1, login_id2)

      assert validated_session.account_id == account_id
      assert validated_session.username == username
      assert DateTime.compare(validated_session.last_activity, original_activity) == :gt
    end

    test "returns :session_not_found if session does not exist" do
      account_id = 104
      login_id1 = 1
      login_id2 = 2

      log =
        capture_log(fn ->
          assert {:error, :session_not_found} =
                   SessionManager.validate_session(account_id, login_id1, login_id2)
        end)

      assert log =~ "Session validation failed for account 104: session_not_found"
    end

    test "returns :invalid_credentials if login IDs do not match" do
      account_id = 105

      session_data = %{
        login_id1: 1,
        login_id2: 2,
        auth_code: 1234,
        username: "wronguser"
      }

      assert :ok = SessionManager.create_session(account_id, session_data)

      log =
        capture_log(fn ->
          assert {:error, :invalid_credentials} =
                   SessionManager.validate_session(account_id, 99, 98)
        end)

      assert log =~ "Session validation failed for account 105: invalid_credentials"
    end
  end

  describe "end_session/1" do
    test "successfully ends session and cleans up online user" do
      account_id = 107

      session_data = %{
        login_id1: 1,
        login_id2: 2,
        auth_code: 1234,
        username: "enduser"
      }

      assert :ok = SessionManager.create_session(account_id, session_data)
      assert :ok = SessionManager.set_user_online(account_id, :account_server)

      assert {:ok, _session} = SessionManager.get_session(account_id)
      assert SessionManager.get_online_count() == 1

      assert :ok = SessionManager.end_session(account_id)

      assert {:error, :not_found} = SessionManager.get_session(account_id)
      assert SessionManager.get_online_count() == 0
    end

    test "successfully ends session even if user is not online" do
      account_id = 108

      session_data = %{
        login_id1: 1,
        login_id2: 2,
        auth_code: 1234,
        username: "offlineuser"
      }

      assert :ok = SessionManager.create_session(account_id, session_data)
      assert :ok = SessionManager.end_session(account_id)

      assert {:error, :not_found} = SessionManager.get_session(account_id)
    end
  end

  describe "get_session/1" do
    test "successfully retrieves existing session" do
      account_id = 109

      session_data = %{
        login_id1: 1,
        login_id2: 2,
        auth_code: 3,
        username: "retrieved_user"
      }

      assert :ok = SessionManager.create_session(account_id, session_data)

      {:ok, session} = SessionManager.get_session(account_id)
      assert session.account_id == account_id
      assert session.username == "retrieved_user"
      assert session.login_id1 == 1
      assert session.login_id2 == 2
      assert session.auth_code == 3
    end

    test "returns :not_found if session does not exist" do
      account_id = 110
      assert {:error, :not_found} = SessionManager.get_session(account_id)
    end
  end

  describe "update_character_location/4" do
    test "successfully updates character location" do
      char_id = 1
      account_id = 112
      map_name = "Prontera"
      x = 100
      y = 200

      assert :ok = SessionManager.update_character_location(char_id, account_id, map_name, {x, y})

      # Verify location was stored
      {:ok, location} =
        Memento.transaction(fn ->
          Memento.Query.read(CharacterLocation, char_id)
        end)

      assert location.char_id == char_id
      assert location.account_id == account_id
      assert location.map_name == map_name
      assert location.x == x
      assert location.y == y
      assert location.zone_server_node == Node.self()
    end

    test "updates existing character location" do
      char_id = 2
      account_id = 113

      # Create initial location
      assert :ok =
               SessionManager.update_character_location(char_id, account_id, "Geffen", {50, 75})

      # Update location
      assert :ok =
               SessionManager.update_character_location(char_id, account_id, "Payon", {100, 150})

      # Verify updated location
      {:ok, location} =
        Memento.transaction(fn ->
          Memento.Query.read(CharacterLocation, char_id)
        end)

      assert location.char_id == char_id
      assert location.account_id == account_id
      assert location.map_name == "Payon"
      assert location.x == 100
      assert location.y == 150
    end
  end

  describe "set_user_online/4" do
    test "successfully sets user online for char_server" do
      account_id = 114
      server_type = :char_server
      username = "onlineuser"

      session_data = %{
        login_id1: 1,
        login_id2: 2,
        auth_code: 1234,
        username: username
      }

      assert :ok = SessionManager.create_session(account_id, session_data)
      assert :ok = SessionManager.set_user_online(account_id, server_type)

      # Verify session state updated
      {:ok, session} = SessionManager.get_session(account_id)
      assert session.state == :char_select
      assert session.current_server == :char_server

      # Verify online user created
      assert SessionManager.get_online_count() == 1
      assert SessionManager.get_online_count(:char_server) == 1
    end

    test "successfully sets user online for zone_server" do
      account_id = 115
      server_type = :zone_server
      char_id = 500
      map_name = "Payon"
      username = "ingameuser"

      session_data = %{
        login_id1: 1,
        login_id2: 2,
        auth_code: 1234,
        username: username
      }

      assert :ok = SessionManager.create_session(account_id, session_data)
      assert :ok = SessionManager.set_user_online(account_id, server_type, char_id, map_name)

      # Verify session state updated
      {:ok, session} = SessionManager.get_session(account_id)
      assert session.state == :in_game
      assert session.current_server == :zone_server
      assert session.current_char_id == char_id

      # Verify online user created with character info
      assert SessionManager.get_online_count() == 1
      assert SessionManager.get_online_count(:zone_server) == 1
    end

    test "returns :session_not_found if session does not exist" do
      account_id = 116
      server_type = :account_server

      log =
        capture_log(fn ->
          assert {:error, :session_not_found} =
                   SessionManager.set_user_online(account_id, server_type)
        end)

      assert log =~ "Failed to set user online: session_not_found"
    end
  end

  describe "get_online_count/1" do
    test "returns correct count for all online users" do
      # Create multiple sessions and set them online
      for {account_id, server_type} <- [
            {1, :account_server},
            {2, :char_server},
            {3, :zone_server}
          ] do
        session_data = %{
          login_id1: account_id,
          login_id2: account_id + 100,
          auth_code: 1234,
          username: "user#{account_id}"
        }

        assert :ok = SessionManager.create_session(account_id, session_data)
        assert :ok = SessionManager.set_user_online(account_id, server_type)
      end

      assert SessionManager.get_online_count() == 3
    end

    test "returns correct count for specific server_type" do
      # Create sessions for different server types
      for {account_id, server_type} <- [
            {1, :account_server},
            {2, :char_server},
            {3, :zone_server},
            {4, :zone_server}
          ] do
        session_data = %{
          login_id1: account_id,
          login_id2: account_id + 100,
          auth_code: 1234,
          username: "user#{account_id}"
        }

        assert :ok = SessionManager.create_session(account_id, session_data)
        assert :ok = SessionManager.set_user_online(account_id, server_type)
      end

      assert SessionManager.get_online_count(:zone_server) == 2
      assert SessionManager.get_online_count(:char_server) == 1
      assert SessionManager.get_online_count(:account_server) == 1
    end

    test "returns 0 if no users are online" do
      assert SessionManager.get_online_count() == 0
    end
  end

  describe "register_server/6" do
    test "successfully registers a new server" do
      server_id = "zone-01"
      server_type = :zone_server
      ip = {127, 0, 0, 1}
      port = 5000
      max_players = 2000
      metadata = %{"region" => "EU"}

      assert :ok =
               SessionManager.register_server(
                 server_id,
                 server_type,
                 ip,
                 port,
                 max_players,
                 metadata
               )

      servers = SessionManager.get_servers()
      assert length(servers) == 1

      server = hd(servers)
      assert server.server_id == server_id
      assert server.server_type == server_type
      assert server.ip == ip
      assert server.port == port
      assert server.max_players == max_players
      assert server.metadata == metadata
      assert server.status == :online
      assert server.player_count == 0
    end

    test "can register multiple servers" do
      servers_data = [
        {"acc-01", :account_server, {1, 1, 1, 1}, 1000},
        {"char-01", :char_server, {2, 2, 2, 2}, 2000},
        {"zone-01", :zone_server, {3, 3, 3, 3}, 3000}
      ]

      for {server_id, server_type, ip, port} <- servers_data do
        assert :ok = SessionManager.register_server(server_id, server_type, ip, port)
      end

      servers = SessionManager.get_servers()
      assert length(servers) == 3
    end
  end

  describe "update_server_heartbeat/2" do
    test "successfully updates server heartbeat and player count" do
      server_id = "zone-03"
      server_type = :zone_server
      ip = {127, 0, 0, 1}
      port = 5002
      player_count = 150

      assert :ok = SessionManager.register_server(server_id, server_type, ip, port)

      original_servers = SessionManager.get_servers()
      original_server = hd(original_servers)
      original_heartbeat = original_server.last_heartbeat

      # Ensure timestamp difference

      :timer.sleep(1)

      assert :ok = SessionManager.update_server_heartbeat(server_id, player_count)

      updated_servers = SessionManager.get_servers()
      updated_server = hd(updated_servers)

      assert updated_server.player_count == player_count
      assert DateTime.compare(updated_server.last_heartbeat, original_heartbeat) == :gt
    end

    test "returns :server_not_found if server does not exist" do
      server_id = "non-existent-server"
      player_count = 10

      assert {:error, :server_not_found} =
               SessionManager.update_server_heartbeat(server_id, player_count)
    end
  end

  describe "get_servers/1" do
    test "returns all registered servers" do
      servers_data = [
        {"acc-01", :account_server, {1, 1, 1, 1}, 1000},
        {"char-01", :char_server, {2, 2, 2, 2}, 2000},
        {"zone-01", :zone_server, {3, 3, 3, 3}, 3000}
      ]

      for {server_id, server_type, ip, port} <- servers_data do
        assert :ok = SessionManager.register_server(server_id, server_type, ip, port)
      end

      servers = SessionManager.get_servers()
      assert length(servers) == 3

      server_ids = Enum.map(servers, & &1.server_id)
      assert "acc-01" in server_ids
      assert "char-01" in server_ids
      assert "zone-01" in server_ids
    end

    test "returns servers filtered by server_type" do
      servers_data = [
        {"acc-01", :account_server, {1, 1, 1, 1}, 1000},
        {"char-01", :char_server, {2, 2, 2, 2}, 2000},
        {"zone-01", :zone_server, {3, 3, 3, 3}, 3000}
      ]

      for {server_id, server_type, ip, port} <- servers_data do
        assert :ok = SessionManager.register_server(server_id, server_type, ip, port)
      end

      char_servers = SessionManager.get_servers(:char_server)
      assert length(char_servers) == 1
      assert hd(char_servers).server_id == "char-01"
      assert hd(char_servers).server_type == :char_server
    end

    test "returns empty list if no servers are registered" do
      assert SessionManager.get_servers() == []
    end
  end

  describe "integration scenarios" do
    test "complete user session flow" do
      account_id = 201
      username = "integration_user"
      char_id = 1001
      map_name = "Prontera"

      session_data = %{
        login_id1: 1,
        login_id2: 2,
        auth_code: 1234,
        username: username
      }

      # 1. Create session
      assert :ok = SessionManager.create_session(account_id, session_data)
      {:ok, session} = SessionManager.get_session(account_id)
      assert session.state == :authenticating
      assert session.current_server == :account_server

      # 2. Move to char server
      assert :ok = SessionManager.set_user_online(account_id, :char_server)
      {:ok, session} = SessionManager.get_session(account_id)
      assert session.state == :char_select
      assert session.current_server == :char_server

      # 3. Enter game
      assert :ok = SessionManager.set_user_online(account_id, :zone_server, char_id, map_name)
      {:ok, session} = SessionManager.get_session(account_id)
      assert session.state == :in_game
      assert session.current_server == :zone_server
      assert session.current_char_id == char_id

      # 4. Update character location
      assert :ok =
               SessionManager.update_character_location(char_id, account_id, map_name, {100, 200})

      # 5. Verify user is online
      assert SessionManager.get_online_count() == 1
      assert SessionManager.get_online_count(:zone_server) == 1

      # 6. End session
      assert :ok = SessionManager.end_session(account_id)
      assert {:error, :not_found} = SessionManager.get_session(account_id)
      assert SessionManager.get_online_count() == 0
    end

    test "multiple concurrent sessions" do
      accounts = [
        {1, "user1", :account_server},
        {2, "user2", :char_server},
        {3, "user3", :zone_server}
      ]

      # Create multiple sessions
      for {account_id, username, server_type} <- accounts do
        session_data = %{
          login_id1: account_id,
          login_id2: account_id + 100,
          auth_code: 1234,
          username: username
        }

        assert :ok = SessionManager.create_session(account_id, session_data)
        assert :ok = SessionManager.set_user_online(account_id, server_type)
      end

      # Verify all sessions exist
      assert SessionManager.get_online_count() == 3
      assert SessionManager.get_online_count(:account_server) == 1
      assert SessionManager.get_online_count(:char_server) == 1
      assert SessionManager.get_online_count(:zone_server) == 1

      # End one session
      assert :ok = SessionManager.end_session(2)
      assert SessionManager.get_online_count() == 2
      assert SessionManager.get_online_count(:char_server) == 0
    end
  end
end
