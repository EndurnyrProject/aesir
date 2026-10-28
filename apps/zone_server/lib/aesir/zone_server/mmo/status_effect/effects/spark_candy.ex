defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SparkCandy do
  @moduledoc """
  Spark Candy buff (SC_SPARKCANDY).

  Fixed +20 ATK and +25% ASPD, independent of `val1`, and damage cannot stop
  the holder walking (no walk delay), at the cost of 100 HP drained every 10
  seconds. Only the duration comes from the consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_sparkcandy,
    remove_on_death: false,
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    calc_flags: [:atk, :aspd_rate],
    icon: :steampack,
    tick_interval: 10_000

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @modifiers %{atk: 20, aspd_rate: 25, no_walk_delay: true}

  @impl true
  def modifiers(_instance, _context), do: @modifiers

  @impl true
  def on_tick(target, instance, _context) do
    deal_damage(target, 100)
    {:ok, instance}
  end
end
