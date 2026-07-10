defmodule Aesir.Commons.InterServer.PubSubTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.InterServer.PubSub

  setup do
    PubSub.subscribe_to_player_events()
    :ok
  end

  describe "broadcast_player_login/2" do
    test "broadcasts player login event" do
      account_id = 100
      username = "test_user"

      assert :ok = PubSub.broadcast_player_login(account_id, username)

      assert_receive {:player_event, event}, 1000
      assert event.event == "player_login"
      assert event.account_id == account_id
      assert event.username == username
      assert event.from_server == :account_server
      assert event.node == Node.self()
      assert %DateTime{} = event.timestamp
    end
  end

  describe "broadcast_player_logout/2" do
    test "broadcasts player logout event" do
      account_id = 101
      username = "logout_user"

      assert :ok = PubSub.broadcast_player_logout(account_id, username)

      assert_receive {:player_event, event}, 1000
      assert event.event == "player_logout"
      assert event.account_id == account_id
      assert event.username == username
      assert event.from_server == :account_server
      assert event.node == Node.self()
      assert %DateTime{} = event.timestamp
    end
  end

  describe "broadcast_kick_connection/2" do
    test "broadcasts kick connection event" do
      account_id = 102
      reason = :duplicate_login

      assert :ok = PubSub.broadcast_kick_connection(account_id, reason)

      assert_receive {:player_event, event}, 1000
      assert event.event == "kick_connection"
      assert event.account_id == account_id
      assert event.reason == :duplicate_login
      assert event.node == Node.self()
      assert %DateTime{} = event.timestamp
    end

    test "broadcasts kick connection with different reason" do
      account_id = 103
      reason = :admin_kick

      assert :ok = PubSub.broadcast_kick_connection(account_id, reason)

      assert_receive {:player_event, event}, 1000
      assert event.event == "kick_connection"
      assert event.account_id == account_id
      assert event.reason == :admin_kick
    end
  end

  describe "server_announce/1" do
    setup do
      PubSub.subscribe_to_announcements()
      :ok
    end

    test "broadcasts a server-wide announce message to subscribers" do
      message = %{nameid: 1201, refine: 10}

      assert :ok = PubSub.server_announce(message)

      assert_receive {:server_announce, event}, 1000
      assert event.event == "server_announce"
      assert event.message == message
      assert event.node == Node.self()
      assert %DateTime{} = event.timestamp
    end

    test "does not leak onto the player events topic" do
      PubSub.subscribe_to_player_events()

      assert :ok = PubSub.server_announce(%{nameid: 1201, refine: 10})

      assert_receive {:server_announce, _event}, 1000
      refute_receive {:player_event, _event}, 200
    end
  end

  describe "broadcast_announcement/1" do
    setup do
      PubSub.subscribe_to_announcements()
      :ok
    end

    test "delivers the given packet as {:announcement, packet} to subscribers" do
      packet = %{text: "server going down", color: 0, style: :TOP, source_name: ""}

      assert :ok = PubSub.broadcast_announcement(packet)

      assert_receive {:announcement, ^packet}, 1000
    end
  end
end
