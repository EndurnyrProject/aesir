defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MindBreaker do
  @moduledoc """
  Mind Breaker (SC_MINDBREAKER). Raises the holder's MATK by 20% and lowers its
  soft MDEF by 12% per level, waking it from Freeze, Stone and Sleep.
  Identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_mindbreaker,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:debuff, :remove_on_hermode],
    no_save: true,
    properties: [:debuff],
    calc_flags: [:matk, :mdef],
    immunity: [:status_immune],
    end_on_start: [:sc_freeze, :sc_stone, :sc_sleep],
    icon: :mindbreaker

  @impl true
  def modifiers(%{val1: level}, _context), do: %{matk_rate: 20 * level, mdef2_rate: -12 * level}
end
