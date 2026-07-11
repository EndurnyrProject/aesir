defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncStr do
  @moduledoc """
  STR buff (SC_INCSTR).

  Raises STR by `val1` for the duration; magnitude and duration come from the
  consumed item's `sc_start`. Mirrors `db/re/status.yml` `Increase_Str` (no icon).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incstr,
    properties: [:buff],
    calc_flags: [:str]

  @impl true
  def modifiers(instance, _context), do: %{str: instance.val1}
end
