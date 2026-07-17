defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicCandy do
  @moduledoc """
  Magic Candy buff (SC_MAGICCANDY).

  Fixed +30 MATK (`db/re/status.yml`: literal `bMatk,30`), independent of `val1`,
  at the cost of 90 SP drained every 10 seconds (rAthena `bSPLossRate,90,10000`).
  Only the duration comes from the consumed item's `sc_start`.
  """
  # NOTE: Deferred riders (no modifier vocabulary yet): fixed-cast time -70% and
  #   NoCastCancel. status.yml defines them alongside the MATK bonus; add them
  #   once a fixed-cast-rate modifier key exists.
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_magiccandy,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:matk],
    icon: :magic_candy,
    tick_interval: 10_000

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @modifiers %{matk: 30}

  @impl true
  def modifiers(_instance, _context), do: @modifiers

  @impl true
  def on_tick(target, instance, _context) do
    consume_sp(target, 90)
    {:ok, instance}
  end
end
