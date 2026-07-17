defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Mysticpowder do
  @moduledoc """
  Mystic Powder buff (SC_MYSTICPOWDER).

  Fixed +20 FLEE and +10 LUK (`db/re/status.yml`: literal `bFlee,20` /
  `bLuk,10`), independent of `val1`. Only the duration comes from the consumed
  item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_mysticpowder,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:flee, :luk],
    icon: :mysticpowder

  @modifiers %{flee: 20, luk: 10}

  @impl true
  def modifiers(_instance, _context), do: @modifiers
end
