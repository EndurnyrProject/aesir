defmodule Aesir.Commons.InterServer.PubSub do
  @moduledoc """
  Phoenix PubSub integration for inter-server communication between account and char servers.
  """

  @pubsub_name Aesir.PubSub

  # Topic definitions for account <-> char communication
  @players_topic "players:auth"
  @characters_topic "characters:events"
  @servers_topic "servers:status"
  @announce_topic "servers:announce"

  # Player Authentication Events (Account -> Char)

  @doc """
  Broadcast player login event from account server to char server.
  """
  def broadcast_player_login(account_id, username) do
    event = %{
      event: "player_login",
      account_id: account_id,
      username: username,
      from_server: :account_server,
      node: Node.self(),
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(@pubsub_name, @players_topic, {:player_event, event})
  end

  @doc """
  Broadcast player logout event.
  """
  def broadcast_player_logout(account_id, username) do
    event = %{
      event: "player_logout",
      account_id: account_id,
      username: username,
      from_server: :account_server,
      node: Node.self(),
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(@pubsub_name, @players_topic, {:player_event, event})
  end

  @doc """
  Broadcast kick connection event to force disconnect an existing connection.
  Used to prevent duplicate logins by terminating the first connection when
  a second login attempt is detected.
  """
  @spec broadcast_kick_connection(account_id :: non_neg_integer(), reason :: atom()) :: :ok
  def broadcast_kick_connection(account_id, reason) do
    event = %{
      event: "kick_connection",
      account_id: account_id,
      reason: reason,
      node: Node.self(),
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(@pubsub_name, @players_topic, {:player_event, event})
  end

  # Character Events (Char -> Account)

  @doc """
  Broadcast character selection event from char server.
  """
  def broadcast_character_selected(account_id, character_id, character_name) do
    event = %{
      event: "character_selected",
      account_id: account_id,
      character_id: character_id,
      character_name: character_name,
      from_server: :char_server,
      node: Node.self(),
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(@pubsub_name, @characters_topic, {:character_event, event})
  end

  @doc """
  Broadcast character creation event from char server.
  """
  def broadcast_character_created(account_id, character_id, character_name) do
    event = %{
      event: "character_created",
      account_id: account_id,
      character_id: character_id,
      character_name: character_name,
      from_server: :char_server,
      node: Node.self(),
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(@pubsub_name, @characters_topic, {:character_event, event})
  end

  # Server Status Events

  @doc """
  Broadcast server status update.
  """
  def broadcast_server_status(server_type, status, player_count \\ 0) do
    event = %{
      event: "server_status",
      server_type: server_type,
      status: status,
      player_count: player_count,
      node: Node.self(),
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(@pubsub_name, @servers_topic, {:server_event, event})
  end

  # Server-Wide Announcements

  @doc """
  Broadcasts a server-wide announcement, e.g. a flagged refine outcome, a WoE
  notice, or a GM broadcast. Every zone `Coordinator` subscribes to this topic
  and relays `message` to its local players.
  """
  @spec server_announce(term()) :: :ok
  def server_announce(message) do
    event = %{
      event: "server_announce",
      message: message,
      node: Node.self(),
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(@pubsub_name, @announce_topic, {:server_announce, event})
  end

  @doc """
  Publishes a fully-built broadcast packet for global fan-out. Every zone
  `Coordinator` subscribes to this topic and delivers `packet` to the players
  on its own map, reaching every online player exactly once without a central
  roster scan.
  """
  @spec broadcast_announcement(term()) :: :ok
  def broadcast_announcement(packet) do
    Phoenix.PubSub.broadcast(@pubsub_name, @announce_topic, {:announcement, packet})
  end

  @doc """
  Subscribes the caller to server-wide announcements.
  """
  def subscribe_to_announcements do
    Phoenix.PubSub.subscribe(@pubsub_name, @announce_topic)
  end

  # Subscription Functions

  @doc """
  Subscribe to player authentication events.
  """
  def subscribe_to_player_events do
    Phoenix.PubSub.subscribe(@pubsub_name, @players_topic)
  end

  @doc """
  Subscribe to character events.
  """
  def subscribe_to_character_events do
    Phoenix.PubSub.subscribe(@pubsub_name, @characters_topic)
  end

  @doc """
  Subscribe to server status events.
  """
  def subscribe_to_server_events do
    Phoenix.PubSub.subscribe(@pubsub_name, @servers_topic)
  end

  @doc """
  Unsubscribe from a topic.
  """
  def unsubscribe(topic) do
    Phoenix.PubSub.unsubscribe(@pubsub_name, topic)
  end
end
