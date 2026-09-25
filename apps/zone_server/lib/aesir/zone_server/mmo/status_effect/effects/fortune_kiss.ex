defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FortuneKiss do
  @moduledoc """
  Renewal Lady Luck is a finite snapshot; pre-renewal holds a field buff
  that lingers on exit.

  Renewal derives flat critical and critical damage from the dance level;
  pre-renewal reads the critical the performer snapshotted at cast and adds no
  critical damage.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_fortunekiss,
    no_dispel: true,
    no_save: [renewal: false, pre_renewal: true],
    properties: [:buff],
    calc_flags: [:critical],
    end_on_start: [
      renewal: [:sc_humming, :sc_dontforgetme, :sc_fortunekiss, :sc_serviceforyou],
      pre_renewal: []
    ],
    duration: 180_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :fortunekiss

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, _context) do
    case GameMode.mode() do
      :renewal -> %{critical: instance.val1, crit_atk_rate: 2 * instance.val1}
      :pre_renewal -> %{critical: instance.val2}
    end
  end
end
