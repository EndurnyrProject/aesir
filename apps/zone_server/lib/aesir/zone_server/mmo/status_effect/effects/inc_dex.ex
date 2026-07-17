defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncDex do
  @moduledoc """
  DEX buff (SC_INCDEX).

  Raises DEX by `val1` for the duration; magnitude and duration come from the
  consumed item's `sc_start`. Mirrors `db/re/status.yml` `Increase_Dex` (no icon).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incdex,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:dex]

  @impl true
  def modifiers(instance, _context), do: %{dex: instance.val1}
end
