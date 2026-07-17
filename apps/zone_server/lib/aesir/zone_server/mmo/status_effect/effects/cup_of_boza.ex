defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CupOfBoza do
  @moduledoc """
  Cup of Boza cooked-food buff (SC_CUP_OF_BOZA).

  Fixed +10 VIT (`db/re/status.yml`: literal `bVit,10`), independent of `val1`.
  Only the duration comes from the consumed item's `sc_start`.
  """
  # NOTE: Deferred rider (no modifier vocabulary yet): +5 fire-element resistance.
  #   status.yml defines it alongside the VIT bonus; add it once an
  #   element-resist modifier key exists.
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_cup_of_boza,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:vit],
    icon: :cup_of_boza

  @modifiers %{vit: 10}

  @impl true
  def modifiers(_instance, _context), do: @modifiers
end
