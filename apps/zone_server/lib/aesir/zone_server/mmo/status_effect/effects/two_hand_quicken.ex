defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.TwoHandQuicken do
  @moduledoc """
  Two-Hand Quicken (SC_TWOHANDQUICKEN).

  ASPD boost (val2) with HIT and CRIT bonuses scaling with the skill level
  (val1). Fails while Decrease AGI is active.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_twohandquicken,
    properties: [:buff],
    calc_flags: [:aspd, :hit, :cri],
    flags: [:require_weapon],
    conflicts_with: [:sc_decreaseagi],
    prevented_by: [:sc_refresh, :sc_inspiration]

  @impl true
  def modifiers(instance, _context) do
    %{
      aspd: instance.val2,
      hit: instance.val1 * 2,
      cri: (2 + instance.val1) * 10
    }
  end
end
