defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ExtractWhitePotionZ do
  @moduledoc """
  Extract White Potion Z buff (SC_EXTRACT_WHITE_POTION_Z).

  Raises HP natural-recovery rate by `val1` percent (`db/re/status.yml`:
  `bHPrecovRate, getstatus(SC_EXTRACT_WHITE_POTION_Z,1)`), consumed through the
  existing `hp_regen` channel in `unit/player/handlers/natural_heal_handler.ex`.
  val1-driven.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_extract_white_potion_z,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:hp_regen],
    icon: :extract_white_potion_z

  @impl true
  def modifiers(instance, _context), do: %{hp_regen: instance.val1}
end
