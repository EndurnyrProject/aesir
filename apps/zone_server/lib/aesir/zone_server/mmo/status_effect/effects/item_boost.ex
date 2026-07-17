defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ItemBoost do
  @moduledoc """
  Item drop-rate boost (SC_ITEMBOOST, Bubble Gum).

  Adds `val1` percent to the killer's drop rate. Modelled as an additive
  `drop_rate` percent delta fetched in `unit/player/player_session.ex`
  `maybe_drop_items/2` and applied before the 90% cap in
  `mmo/item_drop/drop_calculator.ex` (rAthena `mob.cpp:2837-2862`). val1-driven
  (Bubble Gum passes 100).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_itemboost,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:drop_rate],
    icon: :cash_receiveitem

  @impl true
  def modifiers(instance, _context), do: %{drop_rate: instance.val1}
end
