defmodule Aesir.Commons.InterServer.Schemas.ServerStatus do
  @moduledoc """
  Memento schema for tracking server status across the cluster.
  Used for server discovery and health monitoring.
  """
  use Memento.Table,
    attributes: [
      :server_id,
      :server_type,
      :server_node,
      :status,
      :player_count,
      :max_players,
      :ip,
      :port,
      :last_heartbeat,
      :metadata
    ],
    index: [:server_type, :server_node, :status],
    type: :set

  @type t :: %__MODULE__{
          server_id: String.t(),
          server_type: :account_server | :char_server | :zone_server,
          server_node: node(),
          status: :online | :offline | :maintenance,
          player_count: non_neg_integer(),
          max_players: non_neg_integer(),
          ip: :inet.ip_address(),
          port: non_neg_integer(),
          last_heartbeat: DateTime.t(),
          metadata: map()
        }

  def new(server_id, server_type, ip, port, max_players \\ 1000, metadata \\ %{}) do
    %__MODULE__{
      server_id: server_id,
      server_type: server_type,
      server_node: Node.self(),
      status: :online,
      player_count: 0,
      max_players: max_players,
      ip: ip,
      port: port,
      last_heartbeat: DateTime.utc_now(),
      metadata: metadata
    }
  end

  def update_heartbeat(server_status, player_count \\ nil) do
    %{
      server_status
      | last_heartbeat: DateTime.utc_now(),
        player_count: player_count || server_status.player_count
    }
  end

  def update_status(server_status, status) do
    %{server_status | status: status, last_heartbeat: DateTime.utc_now()}
  end

  def update_player_count(server_status, player_count) do
    %{server_status | player_count: player_count, last_heartbeat: DateTime.utc_now()}
  end

  def is_healthy?(server_status, timeout_seconds \\ 30) do
    DateTime.diff(DateTime.utc_now(), server_status.last_heartbeat) < timeout_seconds
  end
end
