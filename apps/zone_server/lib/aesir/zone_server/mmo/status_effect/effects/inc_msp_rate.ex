defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncMspRate do
  @moduledoc """
  Max SP rate buff (SC_INCMSPRATE).

  Adds `val1` percent to maximum SP.
  Val1-driven, no icon; granted by Gospel and by item scripts. Identical in both
  game modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incmsprate,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:max_sp_rate]

  @impl true
  def modifiers(instance, _context), do: %{max_sp_rate: instance.val1}
end
