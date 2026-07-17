defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncHealRate do
  @moduledoc """
  Received-heal-rate boost (SC_INCHEALRATE).

  Adds `val1` percent to the HP a target recovers when healed by a skill or an
  item/script. Modelled as an additive `received_heal_rate` percent delta read
  target-side in `unit/player/handlers/health_handler.ex` `apply_heal/3` (skill
  heals, rAthena `skill.cpp:671-675`) and `script/dsl.ex` `apply_heal/3` (item
  heals, rAthena `pc.cpp:10719-10720`). Natural regen is deliberately untouched
  (separate `hp_regen` channel) to avoid double-dipping. val1-driven.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_inchealrate,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:received_heal_rate],
    icon: :healplus

  @impl true
  def modifiers(instance, _context), do: %{received_heal_rate: instance.val1}
end
