defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IntScroll do
  @moduledoc """
  INT scroll buff (SC_INT_SCROLL).

  Raises INT by `val1` for the duration; magnitude and duration come from the
  consumed item's `sc_start`. Mirrors `db/re/status.yml` `Int_Scroll`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_int_scroll,
    properties: [:buff],
    calc_flags: [:int],
    icon: :int_scroll

  @impl true
  def modifiers(instance, _context), do: %{int: instance.val1}
end
