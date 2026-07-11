defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MustleM do
  @moduledoc """
  Muscle-massage buff (SC_MUSTLE_M).

  Raises max HP by `val1` percent (`db/re/status.yml`: `bMaxHPRate,
  getstatus(SC_MUSTLE_M,1)`), consumed as a `max_hp_rate` delta in
  `unit/player/stats.ex`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_mustle_m,
    properties: [:buff],
    calc_flags: [:max_hp_rate],
    icon: :mustle_m

  @impl true
  def modifiers(instance, _context), do: %{max_hp_rate: instance.val1}
end
