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
end
