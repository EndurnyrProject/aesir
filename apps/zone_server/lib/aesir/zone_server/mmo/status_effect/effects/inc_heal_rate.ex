defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncHealRate do
  @moduledoc """
  Received-heal-rate boost (SC_INCHEALRATE).

  Adds `val1` percent to the HP a target recovers. Skill heals read it as the
  additive `received_heal_rate` modifier in `HealthHandler.apply_heal/3`; item
  heals (`itemheal`) compound `val1` onto their recovery bonus in
  `Unit.Player.ItemHeal`. Flat (`heal`) and percent (`percentheal`) script
  heals and natural regen ignore it.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_inchealrate,
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    calc_flags: [:received_heal_rate],
    icon: :healplus

  @impl true
  def modifiers(instance, _context), do: %{received_heal_rate: instance.val1}
end
