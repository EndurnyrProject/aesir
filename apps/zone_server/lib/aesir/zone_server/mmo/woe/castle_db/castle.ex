defmodule Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle do
  @moduledoc """
  Static castle data: the identity and fixed coordinates of a WoE FE castle.
  """

  use TypedStruct

  @typedoc "A tile in the castle map."
  @type cell :: {non_neg_integer(), non_neg_integer()}

  @typedoc "One of the castle's eight typed guardian mob spawn slots."
  @type slot :: %{type: :soldier | :archer | :knight, cell: cell()}

  typedstruct enforce: true do
    field :id, non_neg_integer()
    field :map, String.t()
    field :name, String.t()
    field :client_id, non_neg_integer()
    field :emperium, cell()
    field :respawn, cell()
    field :treasure, %{box_id: pos_integer(), cells: [cell()]}
    field :guardians, [slot()]
  end
end
