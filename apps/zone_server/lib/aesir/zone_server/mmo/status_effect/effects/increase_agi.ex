defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncreaseAgi do
  @moduledoc """
  Increase AGI (SC_INCREASEAGI).

  Raises AGI (val2) and attack speed by skill level (val1). rAthena's
  `status_calc_speed` applies a flat `max(val, 25)` haste regardless of skill
  level, modelled here as `movement_speed: -25` (negative = faster).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_increaseagi,
    no_dispel: false,
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
      movement_speed: -25,
      aspd: instance.val1
    }
  end
end
