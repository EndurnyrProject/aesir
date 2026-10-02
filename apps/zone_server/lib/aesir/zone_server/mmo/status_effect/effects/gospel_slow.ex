defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.GospelSlow do
  @moduledoc """
  Battle Chant slow (SC_GOSPEL, enemy side).

  One of Gospel's ten afflictions: for 20 seconds the victim moves 75 percent
  slower and attacks slower. The attack-speed penalty rides the rate channel in
  both modes with different magnitudes: 25 in pre-renewal, 75 in renewal. A
  chanting caster never receives it (`prevented_by: [:sc_gospel]`).

  The reference keys both halves of Gospel off one status id with a
  discriminator; Aesir's static status properties force the enemy half onto its
  own id, which shares the Gospel icon.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_gospel_slow,
    no_dispel: false,
    no_save: true,
    properties: [:debuff],
    prevented_by: [:sc_gospel],
    calc_flags: [:speed, :aspd],
    icon: :gospel

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(_instance, _context) do
    aspd_rate = if GameMode.mode() == :renewal, do: -75, else: -25
    %{movement_speed: 75, aspd_rate: aspd_rate}
  end
end
