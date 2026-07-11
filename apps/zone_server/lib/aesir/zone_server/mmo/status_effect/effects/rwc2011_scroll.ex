defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Rwc2011Scroll do
  @moduledoc """
  2011 RWC Scroll buff (SC_2011RWC_SCROLL).

  Fixed combat scroll (`db/re/status.yml`, **not** an EXP/drop buff): +30 ATK,
  +30 MATK, +5% ASPD, -10% max HP, -10% max SP, -5% variable cast time,
  independent of `val1`. Only the duration comes from the consumed item's
  `sc_start`. The combat/ASPD/max-HP-SP deltas are consumed in the combat
  calculators and `unit/player/stats.ex`; `varcast_rate` is inert until Phase 3
  wires the cast-time consumer (harmless extra key in the merged map until then).
  """
  # NOTE: Deferred rider (no modifier vocabulary yet): autospell on-attack.
  #   status.yml defines it alongside the combat bonuses; add it once an
  #   autospell modifier exists.
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_2011rwc_scroll,
    properties: [:buff],
    calc_flags: [:atk, :matk, :aspd_rate, :max_hp_rate, :max_sp_rate, :varcast_rate],
    icon: :"2011rwc_scroll"

  @modifiers %{
    atk: 30,
    matk: 30,
    aspd_rate: 5,
    max_hp_rate: -10,
    max_sp_rate: -10,
    varcast_rate: -5
  }

  @impl true
  def modifiers(_instance, _context), do: @modifiers
end
