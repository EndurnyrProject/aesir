defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AssassinCross do
  @moduledoc """
  Renewal Assassin Cross of Sunset is a finite snapshot; pre-renewal holds a
  field buff that lingers on exit.

  Renewal reads the snapshot as a flat attack speed bonus; pre-renewal reads it
  as an attack speed rate in percent.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_assncross,
    no_dispel: true,
    no_save: [renewal: false, pre_renewal: true],
    properties: [:buff],
    calc_flags: [:aspd, :aspd_rate],
    end_on_start: [
      renewal: [:sc_whistle, :sc_assncross, :sc_poembragi, :sc_appleidun],
      pre_renewal: []
    ],
    duration: 180_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :assassincross

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, _context) do
    case GameMode.mode() do
      :renewal -> %{aspd: instance.val2}
      :pre_renewal -> %{aspd_rate: instance.val2}
    end
  end
end
