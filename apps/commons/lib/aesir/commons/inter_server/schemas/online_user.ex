defmodule Aesir.Commons.InterServer.Schemas.OnlineUser do
  @moduledoc """
  Presence value for a logged-in account. Stored as a Horde.Registry value keyed
  by `{:online, account_id}`; owned by the player's current serving process.
  """

  @type server :: :account_server | :char_server | :zone_server

  @enforce_keys [:account_id]
  defstruct [
    :account_id,
    :username,
    :server_type,
    :server_node,
    :last_seen,
    :character_id,
    :map_name
  ]

  @type t() :: %__MODULE__{
          account_id: non_neg_integer(),
          username: String.t() | nil,
          server_type: server() | nil,
          server_node: node() | nil,
          last_seen: DateTime.t() | nil,
          character_id: non_neg_integer() | nil,
          map_name: String.t() | nil
        }

  @spec new(non_neg_integer(), String.t(), server(), non_neg_integer() | nil, String.t() | nil) ::
          t()
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

  @spec put_map(t(), String.t()) :: t()
  def put_map(user, map_name), do: %{user | map_name: map_name, last_seen: DateTime.utc_now()}
end
