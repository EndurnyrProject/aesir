defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MatkPotion do
  @moduledoc """
  MATK Potion buff (SC_MATKPOTION).

  Raises flat MATK by `val1` (`db/re/status.yml`: `bMatk, getstatus(SC_MATKPOTION,1)`).
  Magnitude and duration come from the consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_matkpotion,
    properties: [:buff],
    calc_flags: [:matk],
    icon: :plusmagicpower

  @impl true
  def modifiers(instance, _context), do: %{matk: instance.val1}
end
