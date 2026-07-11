defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MentalPotion do
  @moduledoc """
  Mental Potion buff (SC_MENTAL_POTION).

  Raises max SP by `val1` percent and reduces skill SP cost by the same percent
  (`db/re/status.yml`: `bMaxSPrate` + `bUseSPrate,-getstatus(...)`). Modelled as a
  `max_sp_rate` delta (consumed in `unit/player/stats.ex`) plus a negated
  `sp_cost_rate` delta (negative = cheaper, consumed in `skill/interpreter.ex`).
  val1-driven.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_mental_potion,
    properties: [:buff],
    calc_flags: [:max_sp_rate, :sp_cost_rate],
    icon: :target_aspd

  @impl true
  def modifiers(instance, _context),
    do: %{max_sp_rate: instance.val1, sp_cost_rate: -instance.val1}
end
