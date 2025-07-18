defmodule Aesir.Commons.InterServer.Schemas.CharacterLocation do
  @moduledoc """
  Memento schema for tracking character locations across zone servers.
  Used for character transfers and location queries.
  """
  use Memento.Table,
    attributes: [
      :char_id,
      :account_id,
      :map_name,
      :x,
      :y,
      :zone_server_node,
      :last_updated
    ],
    index: [:account_id, :map_name, :zone_server_node],
    type: :set

  @type t :: %__MODULE__{
          char_id: non_neg_integer(),
          account_id: non_neg_integer(),
          map_name: String.t(),
          x: non_neg_integer(),
          y: non_neg_integer(),
          zone_server_node: node() | nil,
          last_updated: DateTime.t()
        }

  def new(char_id, account_id, map_name, x, y, zone_server_node \\ nil) do
    %__MODULE__{
      char_id: char_id,
      account_id: account_id,
      map_name: map_name,
      x: x,
      y: y,
      zone_server_node: zone_server_node,
      last_updated: DateTime.utc_now()
    }
  end

  def update_location(char_location, map_name, x, y, zone_server_node \\ nil) do
    %{
      char_location
      | map_name: map_name,
        x: x,
        y: y,
        zone_server_node: zone_server_node || char_location.zone_server_node,
        last_updated: DateTime.utc_now()
    }
  end

  def update_server(char_location, zone_server_node) do
    %{char_location | zone_server_node: zone_server_node, last_updated: DateTime.utc_now()}
  end
end
