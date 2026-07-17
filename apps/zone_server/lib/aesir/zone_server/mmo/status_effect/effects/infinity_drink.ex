defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.InfinityDrink do
  @moduledoc """
  Infinity Drink buff (SC_INFINITY_DRINK).

  Fixed +5% max HP / +5% max SP (`db/re/status.yml`: literal `bMaxHPRate,5` /
  `bMaxSPRate,5`), independent of `val1`. Only the duration comes from the
  consumed item's `sc_start`.
  """
  # NOTE: Deferred riders (no modifier vocabulary yet): critical damage +5%,
  #   ranged damage +5%, magic-element damage +5%, and NoCastCancel. status.yml
  #   defines these alongside the max HP/SP bonuses; add them once the
  #   corresponding keys exist.
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_infinity_drink,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:max_hp_rate, :max_sp_rate],
    icon: :infinity_drink

  @modifiers %{max_hp_rate: 5, max_sp_rate: 5}

  @impl true
  def modifiers(_instance, _context), do: @modifiers
end
