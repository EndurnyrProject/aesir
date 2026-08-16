defmodule Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle do
  @moduledoc """
  Static castle data: the identity and fixed coordinates of a WoE FE castle.
  """

  @enforce_keys [:id, :map, :name, :client_id, :emperium, :respawn]
  defstruct id: nil,
            map: nil,
            name: nil,
            client_id: nil,
            emperium: nil,
            respawn: nil

  @type t() :: %__MODULE__{
          id: non_neg_integer(),
          map: String.t(),
          name: String.t(),
          client_id: non_neg_integer(),
          emperium: {pos_integer(), pos_integer()},
          respawn: {pos_integer(), pos_integer()}
        }
end
