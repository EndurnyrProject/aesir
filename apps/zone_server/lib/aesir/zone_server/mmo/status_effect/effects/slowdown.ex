defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Slowdown do
  @moduledoc """
  Movement-speed slow (SC_SLOWDOWN).

  Slows the player for the duration (`db/re/status.yml` `Slowdown`; items pass
  100). `movement_speed` is positive-is-slower (`status_manager.ex`), so the slow
  emits `val1` unchanged.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_slowdown,
    no_dispel: false,
    properties: [:debuff],
    calc_flags: [:speed]

  @impl true
  def modifiers(instance, _context), do: %{movement_speed: instance.val1}
end
