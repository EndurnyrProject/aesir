defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncMhpRate do
  @moduledoc """
  Max HP rate buff (SC_INCMHPRATE).

  Adds `val1` percent to maximum HP.
  Val1-driven, no icon; granted by Gospel and by item scripts. Identical in both
  game modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incmhprate,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:max_hp_rate]

  @impl true
  def modifiers(instance, _context), do: %{max_hp_rate: instance.val1}
end
