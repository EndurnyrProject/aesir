defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncreaseMaxSp do
  @moduledoc """
  Increase Max SP buff (SC_INCREASE_MAXSP).

  Raises max SP by `val1` percent and natural SP recovery by `val2` percent.
  The maximum bonus shares the equipment percentage stage before ordinary status
  rates. Both bonuses are identical in both modes and end on death, Dispel or buff clearing.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_increase_maxsp,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [:max_sp_rate, :sp_regen],
    icon: :atker_movespeed

  @impl true
  def modifiers(instance, _context),
    do: %{max_sp_equip_rate: instance.val1, sp_regen: instance.val2}
end
