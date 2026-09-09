defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.TwoHandQuicken do
  @moduledoc """
  Two-Hand Quicken (SC_TWOHANDQUICKEN).

  Renewal: a fixed +7 attack speed with +2 HIT per level and +(2 + level)
  CRIT. Pre-renewal: a 30 percent attack speed rate and nothing else. Fails
  while Decrease AGI is active.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_twohandquicken,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:aspd, :aspd_rate, :hit, :cri],
    require_weapon: [:two_handed_sword],
    conflicts_with: [:sc_decreaseagi],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :twohandquicken,
    opt3: :quicken

  alias Aesir.Commons.GameMode

  @classic_aspd_rate 30

  @impl true
  def modifiers(instance, _context) do
    case GameMode.mode() do
      :renewal -> %{aspd: instance.val2, hit: instance.val1 * 2, critical: 2 + instance.val1}
      :pre_renewal -> %{aspd_rate: @classic_aspd_rate}
    end
  end
end
