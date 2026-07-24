defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpearQuicken do
  @moduledoc """
  Spear Quicken (SC_SPEARQUICKEN).

  ASPD boost (val2) with FLEE and CRIT bonuses scaling with the skill level
  (val1). Fails while Decrease AGI is active.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_spearquicken,
    no_dispel: false,
    no_save: true,
    properties: [:buff],
    calc_flags: [:aspd, :flee, :cri],
    require_weapon: [:one_handed_spear, :two_handed_spear],
    conflicts_with: [:sc_decreaseagi],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :spearquicken,
    opt3: :quicken

  @impl true
  def modifiers(instance, _context) do
    %{
      aspd: instance.val2,
      flee: instance.val1 * 2,
      critical: instance.val1 * 3
    }
  end
end
