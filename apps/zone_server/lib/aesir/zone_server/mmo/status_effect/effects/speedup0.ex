defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Speedup0 do
  @moduledoc """
  Movement-speed potion, tier 0 (SC_SPEEDUP0).

  In renewal and pre-renewal, a player-only bonus speed rate of `val1` percent
  for the duration (items pass 25). It competes with equipment's bonus
  speed rate for the strongest, as one item speed term (`:speed_rate_bonus`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_speedup0,
    no_save: true,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    target_types: [:player],
    calc_flags: [:speed],
    icon: :movhaste_horse

  @impl true
  def modifiers(instance, _context), do: %{speed_rate_bonus: instance.val1}
end
