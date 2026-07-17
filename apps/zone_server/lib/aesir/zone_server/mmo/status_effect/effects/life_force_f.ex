defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.LifeForceF do
  @moduledoc """
  Life-force buff (SC_LIFE_FORCE_F).

  Raises max SP by `val1` percent (`db/re/status.yml`: `bMaxSPRate,
  getstatus(SC_LIFE_FORCE_F,1)`), consumed as a `max_sp_rate` delta in
  `unit/player/stats.ex`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_life_force_f,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:max_sp_rate],
    icon: :life_force_f

  @impl true
  def modifiers(instance, _context), do: %{max_sp_rate: instance.val1}
end
