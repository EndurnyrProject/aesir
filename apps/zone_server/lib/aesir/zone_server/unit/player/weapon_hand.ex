defmodule Aesir.ZoneServer.Unit.Player.WeaponHand do
  @moduledoc """
  Per-hand weapon inputs captured from one worn inventory item.
  """

  use TypedStruct

  @typedoc "A weapon's hand-local physical calculation inputs."
  typedstruct enforce: true do
    field :item_id, integer()
    field :subtype, atom()
    field :element, atom()
    field :base_atk, integer()
    field :weapon_level, pos_integer()
    field :refine_atk, non_neg_integer()
    field :overrefine_band, non_neg_integer()
    field :slot, :right_hand | :left_hand
  end
end
