defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DontForgetMe do
  @moduledoc """
  Renewal Slow Grace is a finite snapshot; pre-renewal holds a field debuff
  that lingers on players after they leave.

  Renewal derives the penalties from the dance level; pre-renewal reads the
  attack speed percent and movement percent the performer snapshotted at cast.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_dontforgetme,
    no_dispel: true,
    no_save: [renewal: false, pre_renewal: true],
    properties: [:debuff],
    calc_flags: [:aspd, :speed],
    end_on_start: [
      renewal: [
        :sc_humming,
        :sc_dontforgetme,
        :sc_fortunekiss,
        :sc_serviceforyou,
        :sc_increaseagi,
        :sc_adrenaline,
        :sc_adrenaline2,
        :sc_spearquicken,
        :sc_twohandquicken,
        :sc_onehand,
        :sc_acceleration,
        :sc_merc_quicken
      ],
      pre_renewal: []
    ],
    conflicts_with: [:sc_speedup1],
    duration: 60_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :dontforgetme

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, _context) do
    case GameMode.mode() do
      :renewal -> %{aspd_rate: -3 * instance.val1, movement_speed: 5 + 2 * instance.val1}
      :pre_renewal -> %{aspd_rate: -instance.val2, movement_speed: instance.val3}
    end
  end
end
