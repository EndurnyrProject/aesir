defmodule Aesir.ZoneServer.Unit.Player.WeaponHand do
  @moduledoc """
  Per-hand weapon inputs captured from one worn inventory item.
  """

  @enforce_keys [
    :item_id,
    :subtype,
    :element,
    :base_atk,
    :refine_atk,
    :overrefine_band,
    :slot
  ]
  defstruct @enforce_keys

  @typedoc "A weapon's hand-local physical calculation inputs."
  @type t() :: %__MODULE__{
          item_id: integer(),
          subtype: atom(),
          element: atom(),
          base_atk: integer(),
          refine_atk: non_neg_integer(),
          overrefine_band: non_neg_integer(),
          slot: :right_hand | :left_hand
        }
end
