defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ExtremityFistRecovery do
  @moduledoc """
  Asura recovery (SC_EXTREMITYFIST).

  The self-inflicted aftermath of an Asura Strike. It is non-persistent and
  cannot be dispelled, and for its Renewal duration it halts the caster's
  natural spirit-point regeneration so the drained pool cannot immediately
  refill. The equivalent freeze on the caster's actions is the skill's
  after-cast delay, committed by the skill interpreter, not this status.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_extremityfist,
    no_dispel: true,
    no_save: true,
    bypass_resistance: true,
    properties: [:debuff],
    calc_flags: [:regen],
    duration: 3_000,
    icon: :extremityfist

  @impl true
  def modifiers(_instance, _context), do: %{sp_regen: -100}
end
