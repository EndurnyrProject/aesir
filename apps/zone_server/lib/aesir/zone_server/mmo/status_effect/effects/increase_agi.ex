defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncreaseAgi do
  @moduledoc """
  Increase AGI (SC_INCREASEAGI).

  In both renewal and pre-renewal, raises AGI (val2) and attack speed by
  skill level (val1), with a flat 25% movement haste regardless of level.
  `haste_rate` keeps only the strongest active haste buff.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_increaseagi,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [:agi, :speed, :aspd],
    end_on_start: [:sc_decreaseagi, :sc_adoramus],
    conflicts_with: [:sc_quagmire],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :inc_agi

  @impl true
  def modifiers(instance, _context) do
    %{
      agi: instance.val2,
      haste_rate: 25,
      aspd: instance.val1
    }
  end
end
