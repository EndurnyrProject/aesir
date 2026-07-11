defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Magnificat do
  @moduledoc """
  Magnificat (SC_MAGNIFICAT).

  Doubles SP regeneration.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_magnificat,
    properties: [:buff],
    calc_flags: [:regen],
    prevented_by: [:sc_refresh, :sc_inspiration],
    no_save: true,
    icon: :magnificat

  @impl true
  def modifiers(_instance, _context), do: %{sp_regen: 100}
end
