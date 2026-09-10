defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Humming do
  @moduledoc """
  Finite Focus Ballet HIT snapshot.

  Renewal derives HIT from the dance level; pre-renewal reads the HIT the
  performer snapshotted at cast.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_humming,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:hit],
    end_on_start: [:sc_humming, :sc_dontforgetme, :sc_fortunekiss, :sc_serviceforyou],
    duration: 180_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :humming

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, _context) do
    case GameMode.mode() do
      :renewal -> %{hit: 4 * instance.val1}
      :pre_renewal -> %{hit: instance.val2}
    end
  end
end
