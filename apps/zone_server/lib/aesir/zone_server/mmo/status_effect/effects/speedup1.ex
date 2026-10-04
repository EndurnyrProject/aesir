defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Speedup1 do
  @moduledoc """
  Movement-speed potion, tier 1 (SC_SPEEDUP1).

  In renewal and pre-renewal, grants `val1` percent movement haste for the
  duration (items pass 50). `haste_rate` keeps only the strongest haste buff.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_speedup1,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:speed],
    icon: :movhaste_potion

  @impl true
  def modifiers(instance, _context), do: %{haste_rate: instance.val1}
end
