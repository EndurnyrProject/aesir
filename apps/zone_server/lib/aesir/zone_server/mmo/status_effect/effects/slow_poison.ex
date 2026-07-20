defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SlowPoison do
  @moduledoc """
  Slow Poison (SC_SLOWPOISON).

  Suppresses Poison and Deadly Poison damage ticks while active.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_slowpoison,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:regen],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :slowpoison
end
