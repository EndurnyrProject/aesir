defmodule Aesir.Commons.InterServer.Schemas.ServerStatus do
  @moduledoc """
  Service-discovery value for a running server. Stored as a Horde.Registry value
  keyed by `{:server, server_id}`; owned by a per-node registration process so it
  disappears automatically when the node goes down.
  """

  @type server :: :account_server | :char_server | :zone_server

  @enforce_keys [:server_id]
  defstruct [
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
  ]

  @type t() :: %__MODULE__{
          server_id: String.t(),
          server_type: server() | nil,
          server_node: node() | nil,
          status: :online | :offline | :maintenance | nil,
          player_count: non_neg_integer() | nil,
          max_players: non_neg_integer() | nil,
          ip: :inet.ip_address() | nil,
          port: non_neg_integer() | nil,
          last_heartbeat: DateTime.t() | nil,
          metadata: map() | nil
        }

  @spec new(String.t(), server(), :inet.ip_address(), non_neg_integer(), non_neg_integer(), map()) ::
          t()
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

  @spec put_player_count(t(), non_neg_integer()) :: t()
  def put_player_count(status, count),
    do: %{status | player_count: count, last_heartbeat: DateTime.utc_now()}
end
