defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncreaseMaxHp do
  @moduledoc """
  Raises maximum HP by `val1` percent and natural HP recovery by `val2` percent.
  The maximum bonus shares the equipment percentage stage before ordinary status
  rates. Both bonuses are identical in both modes and end on death, Dispel or buff clearing.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_increase_maxhp,
    target_types: [:player],
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [:max_hp_rate, :hp_regen],
    icon: :atker_aspd

  @impl true
  def modifiers(instance, _context),
    do: %{max_hp_equip_rate: instance.val1, hp_regen: instance.val2}
end
