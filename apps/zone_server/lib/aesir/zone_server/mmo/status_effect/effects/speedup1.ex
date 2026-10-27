defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Speedup1 do
  @moduledoc """
  Movement-speed potion, tier 1 (SC_SPEEDUP1).

  In renewal and pre-renewal, a player-only bonus speed rate of `val1` percent
  for the duration (items pass 50). It competes with equipment's bonus
  speed rate for the strongest, as one item speed term (`:speed_rate_bonus`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_speedup1,
    no_save: true,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    target_types: [:player],
    calc_flags: [:speed],
    icon: :movhaste_potion

  @impl true
  def modifiers(instance, _context), do: %{speed_rate_bonus: instance.val1}
end
