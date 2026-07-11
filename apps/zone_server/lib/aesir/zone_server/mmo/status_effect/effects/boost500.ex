defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Boost500 do
  @moduledoc """
  Boost500 attack-speed buff (SC_BOOST500).

  Raises ASPD by `val1` percent for the duration (`db/re/status.yml` `Boost500`).
  Summed into the ASPD-rate delta.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_boost500,
    properties: [:buff],
    calc_flags: [:aspd],
    icon: :boost500

  @impl true
  def modifiers(instance, _context), do: %{aspd_rate: instance.val1}
end
