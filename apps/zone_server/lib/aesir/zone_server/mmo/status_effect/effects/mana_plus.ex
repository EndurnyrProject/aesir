defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ManaPlus do
  @moduledoc """
  Mana Plus buff (SC_MANA_PLUS).

  Raises flat MATK by `val1` (`db/re/status.yml`: `bMatk, getstatus(SC_MANA_PLUS,1)`).
  Magnitude and duration come from the consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_mana_plus,
    properties: [:buff],
    calc_flags: [:matk],
    icon: :mana_plus

  @impl true
  def modifiers(instance, _context), do: %{matk: instance.val1}
end
