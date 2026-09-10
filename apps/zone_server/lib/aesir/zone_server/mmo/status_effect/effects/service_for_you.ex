defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ServiceForYou do
  @moduledoc """
  Finite Gypsy's Kiss maximum-SP and SP-cost snapshot.

  Renewal derives both rates from the dance level; pre-renewal reads the max SP
  percent and SP cost percent the performer snapshotted at cast.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_serviceforyou,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:max_sp_rate],
    end_on_start: [:sc_humming, :sc_dontforgetme, :sc_fortunekiss, :sc_serviceforyou],
    duration: 180_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :serviceforyou

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, _context) do
    case GameMode.mode() do
      :renewal -> renewal_modifiers(instance.val1)
      :pre_renewal -> %{max_sp_rate: instance.val2, sp_cost_rate: -instance.val3}
    end
  end

  defp renewal_modifiers(level) do
    max_sp_rate = if level < 10, do: 9 + level, else: 20
    %{max_sp_rate: max_sp_rate, sp_cost_rate: -(5 + level)}
  end
end
