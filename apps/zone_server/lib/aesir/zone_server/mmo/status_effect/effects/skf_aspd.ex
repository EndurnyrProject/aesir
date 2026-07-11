defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SkfAspd do
  @moduledoc """
  Eden-group attack-speed food (SC_SKF_ASPD).

  Raises ASPD by `val1` percent for the duration (`db/re/status.yml` `Skf_Aspd`).
  Summed into the ASPD-rate delta.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_skf_aspd,
    properties: [:buff],
    calc_flags: [:aspd],
    icon: :skf_aspd

  @impl true
  def modifiers(instance, _context), do: %{aspd_rate: instance.val1}
end
