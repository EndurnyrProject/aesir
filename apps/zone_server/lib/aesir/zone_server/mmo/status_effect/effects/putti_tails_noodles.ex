defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PuttiTailsNoodles do
  @moduledoc """
  Putti Tails Noodles cooked-food buff (SC_PUTTI_TAILS_NOODLES).

  Raises LUK by `val1` for the duration (`db/re/status.yml`: `bLuk,
  getstatus(SC_PUTTI_TAILS_NOODLES,1)`). Magnitude and duration come from the
  consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_putti_tails_noodles,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:luk],
    icon: :putti_tails_noodles

  @impl true
  def modifiers(instance, _context), do: %{luk: instance.val1}
end
