defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SiromaIceTea do
  @moduledoc """
  Siroma Iced Tea cooked-food buff (SC_SIROMA_ICE_TEA).

  Raises DEX by `val1` for the duration (`db/re/status.yml`: `bDex,
  getstatus(SC_SIROMA_ICE_TEA,1)`). Magnitude and duration come from the
  consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_siroma_ice_tea,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:dex],
    icon: :siroma_ice_tea

  @impl true
  def modifiers(instance, _context), do: %{dex: instance.val1}
end
