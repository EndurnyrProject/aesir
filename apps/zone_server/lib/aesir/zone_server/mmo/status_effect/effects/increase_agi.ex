defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncreaseAgi do
  @moduledoc """
  Increase AGI (SC_INCREASEAGI).

  Raises AGI (val2), attack speed and movement speed by skill level (val1).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_increaseagi,
    properties: [:buff],
    calc_flags: [:agi, :speed, :aspd],
    end_on_start: [:sc_decreaseagi, :sc_adoramus],
    conflicts_with: [:sc_quagmire],
    prevented_by: [:sc_refresh, :sc_inspiration]

  @impl true
  def modifiers(instance, _context) do
    %{
      agi: instance.val2,
      movement_speed: -div((instance.val1 + 1) * 25, 4),
      aspd: instance.val1
    }
  end
end
