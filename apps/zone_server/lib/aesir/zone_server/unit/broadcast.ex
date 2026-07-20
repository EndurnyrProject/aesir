defmodule Aesir.ZoneServer.Unit.Broadcast do
  @moduledoc """
  Helper functions for broadcasting packets to players in the zone server.

  Centralizes the "resolve player session and push a packet" pattern that was
  previously duplicated across combat, mob and movement code.

  Spatial membership defines observer eligibility here. Connected corpses
  remain observers; callers that require living participants must classify
  authoritative unit state before invoking a broadcast.
  """
  require Logger

  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  @doc """
  Sends a packet to a single player by character id.

  Silently ignores players that are no longer registered (e.g. disconnected).
  """
  @spec to_player(integer(), struct()) :: :ok
  def to_player(char_id, packet) do
    case UnitRegistry.get_player_pid(char_id) do
      {:ok, pid} ->
        PlayerSession.send_packet(pid, packet)

      {:error, :not_found} ->
        Logger.debug("Player #{char_id} not found during broadcast, likely disconnected")
        :ok
    end
  end

  @doc """
  Sends a packet to a list of players.

  ## Options
    - `exclude_id`: A character id to skip (e.g. the sender).
  """
  @spec to_players(Enumerable.t(), struct(), keyword()) :: :ok
  def to_players(char_ids, packet, opts \\ []) do
    exclude_id = Keyword.get(opts, :exclude_id)

    char_ids
    |> Enum.reject(&(&1 == exclude_id))
    |> Enum.each(&to_player(&1, packet))
  end

  @doc """
  Sends a packet to every player within `range` cells of a map position.

  Accepts the same `:exclude_id` option as `to_players/3`.
  """
  @spec to_in_range(String.t(), integer(), integer(), integer(), struct(), keyword()) :: :ok
  def to_in_range(map_name, x, y, range, packet, opts \\ []) do
    map_name
    |> SpatialIndex.get_players_in_range(x, y, range)
    |> to_players(packet, opts)
  end

  @doc """
  Broadcasts a packet to all visible players tracked in the game state.

  Accepts the same `:exclude_id` option as `to_players/3`.
  """
  @spec to_visible_players(map(), struct(), keyword()) :: :ok
  def to_visible_players(game_state, packet, opts \\ []) do
    to_players(game_state.visible_players, packet, opts)
  end

  @doc """
  Subscribes the calling process to mob despawn events for a map.

  Player sessions subscribe at spawn so they can drop a combat target when the
  mob they were attacking dies, without the mob having to know about them.
  """
  @spec subscribe_mob_despawns(String.t()) :: :ok
  def subscribe_mob_despawns(map_name) do
    PubSub.subscribe(Aesir.PubSub, mob_despawn_topic(map_name))
  end

  @doc """
  Unsubscribes the calling process from a map's mob despawn events.

  Used when a player warps away so the session stops reacting to mob despawns on
  the map it just left.
  """
  @spec unsubscribe_mob_despawns(String.t()) :: :ok
  def unsubscribe_mob_despawns(map_name) do
    PubSub.unsubscribe(Aesir.PubSub, mob_despawn_topic(map_name))
  end

  @doc """
  Publishes a mob despawn so players on that map can react (e.g. clear combat).
  """
  @spec publish_mob_despawn(String.t(), integer()) :: :ok
  def publish_mob_despawn(map_name, mob_id) do
    PubSub.broadcast(Aesir.PubSub, mob_despawn_topic(map_name), {:mob_despawned, mob_id})
  end

  # Normalized so the topic matches whether or not the caller's map name still
  # carries the ".gat" suffix (mobs keep it, players don't).
  defp mob_despawn_topic(map_name) do
    "zone:#{String.replace_suffix(map_name, ".gat", "")}:mob_despawns"
  end
end
