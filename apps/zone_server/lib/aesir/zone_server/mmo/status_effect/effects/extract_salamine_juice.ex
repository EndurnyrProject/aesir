defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ExtractSalamineJuice do
  @moduledoc """
  Extract Salamine Juice attack-speed buff (SC_EXTRACT_SALAMINE_JUICE).

  Raises ASPD by `val1` percent for the duration (`db/re/status.yml`
  `Extract_Salamine_Juice`). Summed into the ASPD-rate delta.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_extract_salamine_juice,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:aspd],
    icon: :extract_salamine_juice

  @impl true
  def modifiers(instance, _context), do: %{aspd_rate: instance.val1}
end
