defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Speedup0 do
  @moduledoc """
  Movement-speed potion, tier 0 (SC_SPEEDUP0).

  In renewal and pre-renewal, grants `val1` percent movement haste for the
  duration (items pass 25). `haste_rate` keeps only the strongest haste buff.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_speedup0,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [:speed],
    icon: :movhaste_horse

  @impl true
  def modifiers(instance, _context), do: %{haste_rate: instance.val1}
end
