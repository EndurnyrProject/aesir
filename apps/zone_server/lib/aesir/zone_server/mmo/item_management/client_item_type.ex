defmodule Aesir.ZoneServer.Mmo.ItemManagement.ClientItemType do
  @moduledoc """
  Maps an `ItemDefinition` type atom to the client `IT_*` enum integer used in
  inventory/pickup packets.

  Values are taken verbatim from rAthena's `enum item_types` (src/common/mmo.hpp);
  note the gaps at 1 (`IT_UNKNOWN`), 9 (`IT_UNKNOWN2`) and the jump to 18 for cash.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition

  @client_types %{
    healing: 0,
    usable: 2,
    etc: 3,
    armor: 4,
    weapon: 5,
    card: 6,
    pet_egg: 7,
    pet_armor: 8,
    ammo: 10,
    delay_consume: 11,
    shadow_gear: 12,
    cash: 18
  }

  @doc """
  Returns the client `IT_*` enum integer for an item-type atom, falling back to
  `IT_ETC` (3) for any unmapped atom.
  """
  @spec to_client_type(ItemDefinition.item_type()) :: non_neg_integer()
  def to_client_type(type) when is_atom(type), do: Map.get(@client_types, type, 3)
end
