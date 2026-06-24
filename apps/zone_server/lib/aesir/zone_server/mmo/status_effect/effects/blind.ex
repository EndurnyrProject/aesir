defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Blind do
  @moduledoc """
  Blind (SC_BLIND).

  Reduces HIT and FLEE by 25.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_blind,
    properties: [:debuff],
    calc_flags: [:hit, :flee],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection],
    opt2: :blind

  @impl true
  def modifiers(_instance, _context), do: %{hit: -25, flee: -25}
end
