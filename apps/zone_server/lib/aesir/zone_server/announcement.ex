defmodule Aesir.ZoneServer.Announcement do
  @moduledoc """
  Delivery hub for broadcast messages. Turns a normalized payload plus a scope
  into a single `Aesir.Net.Announcement` packet and routes delivery.

  Local scopes (self/map/area) fan out through the per-map `SpatialIndex` and
  `Unit.Broadcast` helpers; the global scope publishes once to the inter-server
  `servers:announce` topic, where every `Coordinator` delivers the packet to
  the players on its own map.
  """

  alias Aesir.Commons.InterServer.PubSub
  alias Aesir.Net.Announcement, as: AnnouncementMsg
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @type opts :: %{
          text: String.t(),
          color: non_neg_integer(),
          style: :TOP | :CENTER | :LOCAL,
          source_name: String.t()
        }

  @doc """
  Delivers a broadcast to a single player.
  """
  @spec to_self(integer(), opts()) :: :ok
  def to_self(char_id, opts) do
    Broadcast.to_player(char_id, build(opts))
  end

  @doc """
  Delivers a broadcast to every player on a map.
  """
  @spec to_map(String.t(), opts()) :: :ok
  def to_map(map_name, opts) do
    deliver_local(build(opts), map_name)
  end

  @doc """
  Delivers a broadcast to players on a map whose cell is inside the inclusive
  rectangle `{x0, y0, x1, y1}`.
  """
  @spec to_area(String.t(), {integer(), integer(), integer(), integer()}, opts()) :: :ok
  def to_area(map_name, {x0, y0, x1, y1}, opts) do
    packet = build(opts)

    map_name
    |> SpatialIndex.get_players_on_map()
    |> Enum.filter(&in_rectangle?(&1, map_name, x0, y0, x1, y1))
    |> Broadcast.to_players(packet)
  end

  @doc """
  Publishes a broadcast to every online player across all nodes via the
  inter-server fan-out.
  """
  @spec to_all(opts()) :: :ok
  def to_all(opts) do
    PubSub.broadcast_announcement(build(opts))
  end

  @doc """
  Fans an already-built packet to every player on a map. Used by the
  `Coordinator` when it receives a global announcement.
  """
  @spec deliver_local(AnnouncementMsg.t(), String.t()) :: :ok
  def deliver_local(packet, map_name) do
    map_name
    |> SpatialIndex.get_players_on_map()
    |> Broadcast.to_players(packet)
  end

  @spec build(opts()) :: AnnouncementMsg.t()
  defp build(%{text: text, color: color, style: style, source_name: source_name}) do
    %AnnouncementMsg{text: text, color: color, style: style, source_name: source_name}
  end

  defp in_rectangle?(char_id, map_name, x0, y0, x1, y1) do
    case SpatialIndex.get_position(char_id) do
      {:ok, {x, y, ^map_name}} ->
        x >= x0 and x <= x1 and y >= y0 and y <= y1

      _ ->
        false
    end
  end
end
