defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SparkCandy do
  @moduledoc """
  Spark Candy buff (SC_SPARKCANDY).

  Fixed +20 ATK and +25% ASPD (`db/re/status.yml`: literal `bBaseAtk,20` /
  `bAspdRate,25`), independent of `val1`, at the cost of 100 HP drained every 10
  seconds (rAthena `bHPLossRate,100,10000`). Only the duration comes from the
  consumed item's `sc_start`.
  """
  # NOTE: Deferred rider (no modifier vocabulary yet): NoWalkDelay. status.yml
  #   defines it alongside the ATK/ASPD bonuses; add it once a walk-delay
  #   modifier exists.
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_sparkcandy,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:atk, :aspd_rate],
    icon: :steampack,
    tick_interval: 10_000

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @modifiers %{atk: 20, aspd_rate: 25}

  @impl true
  def modifiers(_instance, _context), do: @modifiers

  @impl true
  def on_tick(target, instance, _context) do
    deal_damage(target, 100)
    {:ok, instance}
  end
end
