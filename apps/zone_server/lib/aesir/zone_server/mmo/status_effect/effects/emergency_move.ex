defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EmergencyMove do
  @moduledoc """
  Emergency Move (SC_EMERGENCY_MOVE). Guild area buff granting +25% movement
  speed for the duration (negative modifier = faster, matching IncreaseAgi).

  Known divergence: the reference takes the strongest single haste bonus,
  while this codebase's movement_speed modifiers stack additively (as every
  existing speed buff does); revisit as a class if speed stacking is reworked.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_emergency_move,
    properties: [:buff],
    no_dispel: true,
    no_save: true,
    calc_flags: [:speed]

  @modifiers %{movement_speed: -25}

  @impl true
  def modifiers(_instance, _context), do: @modifiers
end
