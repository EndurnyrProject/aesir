defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DroceraHerbSteamed do
  @moduledoc """
  Drocera Herb Salad cooked-food buff (SC_DROCERA_HERB_STEAMED).

  Raises AGI by `val1` for the duration (`db/re/status.yml`: `bAgi,
  getstatus(SC_DROCERA_HERB_STEAMED,1)`). Magnitude and duration come from the
  consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_drocera_herb_steamed,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:agi],
    icon: :drocera_herb_steamed

  @impl true
  def modifiers(instance, _context), do: %{agi: instance.val1}
end
