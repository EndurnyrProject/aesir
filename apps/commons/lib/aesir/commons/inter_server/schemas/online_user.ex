defmodule Aesir.Commons.InterServer.Schemas.OnlineUser do
  @moduledoc """
  Presence value for a logged-in account. Stored as a Horde.Registry value keyed
  by `{:online, account_id}`; owned by the player's current serving process.
  """
  use TypedStruct

  @type server :: :account_server | :char_server | :zone_server

  typedstruct do
    field :account_id, non_neg_integer(), enforce: true
    field :username, String.t()
    field :server_type, server()
    field :server_node, node()
    field :last_seen, DateTime.t()
    field :character_id, non_neg_integer() | nil
    field :map_name, String.t() | nil
  end

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
