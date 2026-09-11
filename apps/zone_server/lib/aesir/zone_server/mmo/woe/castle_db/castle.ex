defmodule Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle do
  @moduledoc """
  Static castle data: the identity and fixed coordinates of a WoE FE castle.
  """

  @enforce_keys [:id, :map, :name, :client_id, :emperium, :respawn, :treasure, :guardians]
  defstruct id: nil,
            map: nil,
            name: nil,
            client_id: nil,
            emperium: nil,
            respawn: nil,
            treasure: nil,
            guardians: nil

  @typedoc "One of the castle's eight typed guardian mob spawn slots."
  @type slot() :: %{type: :soldier | :archer | :knight, cell: {pos_integer(), pos_integer()}}

  @type t() :: %__MODULE__{
          id: non_neg_integer(),
          map: String.t(),
          name: String.t(),
          client_id: non_neg_integer(),
          emperium: {pos_integer(), pos_integer()},
          respawn: {pos_integer(), pos_integer()},
          treasure: %{box_id: pos_integer(), cells: [{pos_integer(), pos_integer()}]},
          guardians: [slot()]
        }
end
