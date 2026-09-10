defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ViolentGale do
  @moduledoc """
  Violent Gale (SC_VIOLENTGALE), the wind field buff left by the Sage's Violent
  Gale.

  Every occupant's wind attack gains the tabulated element points. FLEE rises by 3
  per level: for everyone in renewal, for wind-element holders only in pre-renewal.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_violentgale,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:flee],
    no_save: true,
    icon: :groundmagic

  alias Aesir.ZoneServer.Mmo.StatusEffect.FieldElement

  @impl true
  def modifiers(instance, context) do
    level = instance.val1
    ratio = %{{:element_ratio, :wind} => FieldElement.enchant_bonus(level)}

    if FieldElement.stat_bonus?(context, :wind),
      do: Map.put(ratio, :flee, 3 * level),
      else: ratio
  end
end
