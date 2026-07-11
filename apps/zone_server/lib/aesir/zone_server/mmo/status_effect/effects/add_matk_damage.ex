defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AddMatkDamage do
  @moduledoc """
  Added magic-damage buff (SC_ADD_MATK_DAMAGE).

  Adds `val1` percent to magic damage (`db/re/status.yml` `bonus bMatkRate`).
  Modelled with the same `matk_rate` percent delta the magic damage calculator
  consumes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_add_matk_damage,
    properties: [:buff],
    calc_flags: [:matk_rate],
    icon: :add_matk_damage

  @impl true
  def modifiers(instance, _context), do: %{matk_rate: instance.val1}
end
