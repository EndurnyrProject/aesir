defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Vitata500 do
  @moduledoc """
  Vitata 500 grants 20% natural SP recovery and 5% maximum SP, regardless of its values.
  The maximum bonus shares equipment's percentage stage before ordinary status
  rates. Identical in both modes; survives Dispel and buff clearing, but ends on death.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_vitata_500,
    target_types: [:player],
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    calc_flags: [:max_sp_rate, :sp_regen],
    icon: :vitata_500

  @impl true
  def modifiers(_instance, _context), do: %{max_sp_equip_rate: 5, sp_regen: 20}
end
