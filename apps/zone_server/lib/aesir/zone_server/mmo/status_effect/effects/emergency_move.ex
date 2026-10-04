defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EmergencyMove do
  @moduledoc """
  Emergency Move (SC_EMERGENCY_MOVE). Guild area buff granting +25% movement
  speed for the duration in both renewal and pre-renewal. Its `haste_rate`
  keeps only the strongest active haste buff, matching Increase AGI.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_emergency_move,
    properties: [:buff],
    no_dispel: true,
    no_save: true,
    calc_flags: [:speed]

  @modifiers %{haste_rate: 25}

  @impl true
  def modifiers(_instance, _context), do: @modifiers
end
