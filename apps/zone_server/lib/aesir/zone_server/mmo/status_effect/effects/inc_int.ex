defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncInt do
  @moduledoc """
  INT buff (SC_INCINT).

  Raises INT by `val1` for the duration; magnitude and duration come from the
  consumed item's `sc_start`. Mirrors `db/re/status.yml` `Increase_Int` (no icon).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incint,
    properties: [:buff],
    calc_flags: [:int]

  @impl true
  def modifiers(instance, _context), do: %{int: instance.val1}
end
