defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncLuk do
  @moduledoc """
  LUK buff (SC_INCLUK).

  Raises LUK by `val1` for the duration; magnitude and duration come from the
  consumed item's `sc_start`. Mirrors `db/re/status.yml` `Increase_Luk` (no icon).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incluk,
    properties: [:buff],
    calc_flags: [:luk]

  @impl true
  def modifiers(instance, _context), do: %{luk: instance.val1}
end
