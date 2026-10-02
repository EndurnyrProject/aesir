defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncFleeRate do
  @moduledoc """
  FLEE rate modifier (SC_INCFLEERATE).

  Adds `val1` percent to FLEE; negative values (Gospel's -100% curse) reduce it.
  Val1-driven, no icon; granted by Gospel and by item scripts. Identical in both
  game modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incfleerate,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:flee_rate]

  @impl true
  def modifiers(instance, _context), do: %{flee_rate: instance.val1}
end
