defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncreaseMaxSp do
  @moduledoc """
  Increase Max SP buff (SC_INCREASE_MAXSP).

  Raises max SP by `val1` percent (`db/re/status.yml`: `bMaxSPRate,
  getstatus(SC_INCREASE_MAXSP,1)`), consumed as a `max_sp_rate` delta in
  `unit/player/stats.ex`.
  """
  # NOTE: rAthena starts this status with sc_start2; val2 is a secondary SP
  #   natural-recovery bonus. Per the sc_start2 codegen decision (architecture
  #   2 / 4.2) the transpiler carries only val1, so the val2 SP-recovery rider
  #   is dropped. Restore it if 4-arg sc_start codegen ever lands.
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_increase_maxsp,
    properties: [:buff],
    calc_flags: [:max_sp_rate],
    icon: :atker_movespeed

  @impl true
  def modifiers(instance, _context), do: %{max_sp_rate: instance.val1}
end
