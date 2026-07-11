defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AtthasteCash do
  @moduledoc """
  Cash attack-speed buff (SC_ATTHASTE_CASH).

  Raises ASPD by `val1` percent for the duration (`db/re/status.yml`
  `Atthaste_Cash`; items pass 3). Summed into the ASPD-rate delta.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_atthaste_cash,
    properties: [:buff],
    calc_flags: [:aspd],
    icon: :atthaste_cash

  @impl true
  def modifiers(instance, _context), do: %{aspd_rate: instance.val1}
end
