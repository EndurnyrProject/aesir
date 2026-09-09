defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.OverThrust do
  @moduledoc """
  Percentage physical-attack buff (SC_OVERTHRUST).

  The caster supplies the percent per application in `val1` (the caster's own buff
  is stronger than the party version at the same skill level), so this definition
  carries no per-level table. The `atk_rate` delta is consumed by the damage
  calculator. The pre-renewal 0.1% weapon-break chance on the caster's attacks is
  not modelled; renewal has none.
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
