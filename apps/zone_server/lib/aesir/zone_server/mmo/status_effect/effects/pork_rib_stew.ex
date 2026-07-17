defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PorkRibStew do
  @moduledoc """
  Pork Rib Stew cooked-food buff (SC_PORK_RIB_STEW).

  Fixed +5% ASPD and -2% skill SP cost (`db/re/status.yml`: literal `bAspdRate,5`
  / `bUseSPrate,-2`), independent of `val1`. Only the duration comes from the
  consumed item's `sc_start`. The `aspd_rate` delta is consumed in
  `unit/player/stats.ex`; `sp_cost_rate` is inert until Phase 3 wires the
  skill-interpreter consumer (harmless extra key in the merged map until then).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_pork_rib_stew,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:aspd_rate, :sp_cost_rate],
    icon: :pork_rib_stew

  @modifiers %{aspd_rate: 5, sp_cost_rate: -2}

  @impl true
  def modifiers(_instance, _context), do: @modifiers
end
