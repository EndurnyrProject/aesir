defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpearQuicken do
  @moduledoc """
  Spear Quicken (SC_SPEARQUICKEN). Fails while Decrease AGI is active and ends when
  the spear is unequipped.

  Renewal: a flat attack speed boost (`val2`) with +2 FLEE and +3 CRIT per level
  (`val1`). Pre-renewal: a 20 plus 1 per level percent attack speed rate only.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_spearquicken,
    no_dispel: false,
    no_save: true,
    properties: [:buff],
    calc_flags: [:aspd, :aspd_rate, :flee, :cri],
    require_weapon: [:one_handed_spear, :two_handed_spear],
    conflicts_with: [:sc_decreaseagi],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :spearquicken,
    opt3: :quicken

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, _context) do
    case GameMode.mode() do
      :renewal -> %{aspd: instance.val2, flee: instance.val1 * 2, critical: instance.val1 * 3}
      :pre_renewal -> %{aspd_rate: 20 + instance.val1}
    end
  end
end
