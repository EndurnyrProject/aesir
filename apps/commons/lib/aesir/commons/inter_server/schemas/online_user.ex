defmodule Aesir.Commons.InterServer.Schemas.OnlineUser do
  @moduledoc """
  Memento schema for tracking online players across the cluster.
  Used for player counts and online status checks.
  """
  use Memento.Table,
    attributes: [
      :account_id,
      :username,
      :server_type,
      :server_node,
      :last_seen,
      :character_id,
      :map_name
    ],
    index: [:username, :server_type, :server_node],
    type: :set

  @type t :: %__MODULE__{
          account_id: non_neg_integer(),
          username: String.t(),
          server_type: :account_server | :char_server | :zone_server,
          server_node: node(),
          last_seen: DateTime.t(),
          character_id: non_neg_integer() | nil,
          map_name: String.t() | nil
        }

  def new(account_id, username, server_type, character_id \\ nil, map_name \\ nil) do
    %__MODULE__{
      account_id: account_id,
      username: username,
      server_type: server_type,
      server_node: Node.self(),
      last_seen: DateTime.utc_now(),
      character_id: character_id,
      map_name: map_name
    }
  end

  def update_location(online_user, character_id, map_name) do
    %{online_user | character_id: character_id, map_name: map_name, last_seen: DateTime.utc_now()}
  end

  def update_server(online_user, server_type) do
    %{
      online_user
      | server_type: server_type,
        server_node: Node.self(),
        last_seen: DateTime.utc_now()
    }
  end

  def touch(online_user) do
    %{online_user | last_seen: DateTime.utc_now()}
  end
end
