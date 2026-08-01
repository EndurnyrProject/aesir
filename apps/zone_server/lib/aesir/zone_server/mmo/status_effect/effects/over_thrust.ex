defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.OverThrust do
  @moduledoc """
  Percentage physical-attack buff (SC_OVERTHRUST).

  The caster supplies the percent per application in `val1` — the caster's own
  buff is stronger than the party version at the same skill level — so this
  definition carries no per-level table. The `atk_rate` delta is consumed in
  `Combat.DamageCalculator`. Renewal grants no weapon-break penalty.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_overthrust,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:atk],
    icon: :overthrust

  @impl true
  def modifiers(instance, _context), do: %{atk_rate: instance.val1}
end
