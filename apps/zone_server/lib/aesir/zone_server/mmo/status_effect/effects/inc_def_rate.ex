defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncDefRate do
  @moduledoc """
  DEF rate modifier (SC_INCDEFRATE).

  Adds `val1` percent to DEF; negative values (Gospel's -100% curse) reduce it.
  Val1-driven, no icon; granted by Gospel and by item scripts. Identical in both
  game modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incdefrate,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:def_rate]

  @impl true
  def modifiers(instance, _context), do: %{def_rate: instance.val1}
end
