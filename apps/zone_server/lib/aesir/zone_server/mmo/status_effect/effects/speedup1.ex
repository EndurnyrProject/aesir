defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Speedup1 do
  @moduledoc """
  Movement-speed potion, tier 1 (SC_SPEEDUP1).

  Speeds the player for the duration (`db/re/status.yml` `Speedup1`; items pass
  50). `movement_speed` is positive-is-slower (`status_manager.ex`), so a speed
  buff emits the negated `val1`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_speedup1,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:speed],
    icon: :movhaste_potion

  @impl true
  def modifiers(instance, _context), do: %{movement_speed: -instance.val1}
end
