defmodule Aesir.ZoneServer.Mmo.ItemManagement.UseEffect do
  @moduledoc """
  One-shot `EF_*` effect shown when a player uses certain consumables.

  The RO client draws these from the item id it receives in the area-broadcast
  use acknowledgement. Aesir's `ItemUseResult` only reaches the user and has no
  item id, so the server plays the effect instead, to every player in view.
  Items that already fire their own effect from their script are not listed.
  """

  alias Aesir.ZoneServer.Unit.SpecialEffect

  @effects %{
    501 => :potion1,
    502 => :potion2,
    503 => :potion3,
    504 => :potion4,
    505 => :potion5,
    506 => :potion6,
    545 => :potion1,
    546 => :potion3,
    547 => :potion4,
    645 => :potion_con,
    656 => :potion_,
    657 => :potion_berserk
  }

  @doc "Plays the use effect of `item_id` on the player, if the item has one."
  @spec play(integer(), integer()) :: :ok
  def play(char_id, item_id) do
    case Map.fetch(@effects, item_id) do
      {:ok, effect} -> SpecialEffect.play({:player, char_id}, effect, :area)
      :error -> :ok
    end
  end
end
