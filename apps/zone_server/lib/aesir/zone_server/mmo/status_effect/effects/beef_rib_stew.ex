defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.BeefRibStew do
  @moduledoc """
  Beef Rib Stew cooked-food buff (SC_BEEF_RIB_STEW).

  Fixed -5% variable cast time and -3% skill SP cost (`db/re/status.yml`: literal
  `bVariableCastrate,-5` / `bUseSPrate,-3`), independent of `val1`. Only the
  duration comes from the consumed item's `sc_start`. The `varcast_rate` delta is
  consumed in `skill/cast_time.ex`; `sp_cost_rate` in `skill/interpreter.ex`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_beef_rib_stew,
    properties: [:buff],
    calc_flags: [:varcast_rate, :sp_cost_rate],
    icon: :beef_rib_stew

  @modifiers %{varcast_rate: -5, sp_cost_rate: -3}

  @impl true
  def modifiers(_instance, _context), do: @modifiers
end
