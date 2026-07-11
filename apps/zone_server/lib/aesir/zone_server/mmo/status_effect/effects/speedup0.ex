defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Speedup0 do
  @moduledoc """
  Movement-speed potion, tier 0 (SC_SPEEDUP0).

  Speeds the player for the duration (`db/re/status.yml` `Speedup0`; items pass
  25). `movement_speed` is positive-is-slower (`status_manager.ex`), so a speed
  buff emits the negated `val1`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_speedup0,
    properties: [:buff],
    calc_flags: [:speed],
    icon: :movhaste_horse

  @impl true
  def modifiers(instance, _context), do: %{movement_speed: -instance.val1}
end
