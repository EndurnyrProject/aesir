defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MinorBbq do
  @moduledoc """
  Minorous BBQ cooked-food buff (SC_MINOR_BBQ).

  Raises VIT by `val1` for the duration (`db/re/status.yml`: `bVit,
  getstatus(SC_MINOR_BBQ,1)`). Magnitude and duration come from the consumed
  item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_minor_bbq,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:vit],
    icon: :minor_bbq

  @impl true
  def modifiers(instance, _context), do: %{vit: instance.val1}
end
