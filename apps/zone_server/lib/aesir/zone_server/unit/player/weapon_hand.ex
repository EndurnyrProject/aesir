defmodule Aesir.ZoneServer.Unit.Player.WeaponHand do
  @moduledoc """
  Per-hand weapon inputs captured from one worn inventory item.

  `base_atk` is the hand's weapon ATK (the reference's `weapon_atk.atk`): the
  item's ATK plus the hand's item-script weapon ATK bonuses (bAtk), held in
  `0..65_535`. `bonus_atk` is the part of `base_atk` those bonuses added.
  """

  use TypedStruct

  @max_atk 65_535

  @typedoc "A weapon's hand-local physical calculation inputs."
  typedstruct enforce: true do
    field :item_id, integer()
    field :subtype, atom()
    field :element, atom()
    field :base_atk, integer()
    field :bonus_atk, integer(), default: 0
    field :weapon_level, pos_integer()
    field :refine_atk, non_neg_integer()
    field :overrefine_band, non_neg_integer()
    field :slot, :right_hand | :left_hand
  end

  @doc """
  A hand's weapon ATK from its item ATK and bAtk bonus total, held in
  `0..65_535` like the reference's `SP_ATK1` accumulation.
  """
  @spec weapon_atk(integer(), integer()) :: 0..65_535
  def weapon_atk(item_atk, bonus), do: (item_atk + bonus) |> max(0) |> min(@max_atk)
end
