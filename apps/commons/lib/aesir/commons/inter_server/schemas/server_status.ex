defmodule Aesir.Commons.InterServer.Schemas.ServerStatus do
  @moduledoc """
  Service-discovery value for a running server. Stored as a Horde.Registry value
  keyed by `{:server, server_id}`; owned by a per-node registration process so it
  disappears automatically when the node goes down.
  """
  use TypedStruct

  @type server :: :account_server | :char_server | :zone_server

  typedstruct do
    field :server_id, String.t(), enforce: true
    field :server_type, server()
    field :server_node, node()
    field :status, :online | :offline | :maintenance
    field :player_count, non_neg_integer()
    field :max_players, non_neg_integer()
    field :ip, :inet.ip_address()
    field :port, non_neg_integer()
    field :last_heartbeat, DateTime.t()
    field :metadata, map()
  end

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
