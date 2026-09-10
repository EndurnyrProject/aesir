defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Deluge do
  @moduledoc """
  Deluge (SC_DELUGE), the water field buff left by the Sage's Deluge.

  Every occupant's water attack gains the tabulated element points. Max HP rises
  by 5, 9, 12, 14, or 15% by level: for everyone in renewal, for water-element
  holders only in pre-renewal. A mob recomputes its stored HP ceiling when the
  status applies or ends.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_deluge,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:max_hp_rate],
    no_save: true,
    icon: :groundmagic

  alias Aesir.ZoneServer.Mmo.StatusEffect.FieldElement

  @hp_rate {5, 9, 12, 14, 15}

  @impl true
  def modifiers(instance, context) do
    level = instance.val1
    ratio = %{{:element_ratio, :water} => FieldElement.enchant_bonus(level)}

    if FieldElement.stat_bonus?(context, :water),
      do: Map.put(ratio, :max_hp_rate, elem(@hp_rate, max(rem(level - 1, 5), 0))),
      else: ratio
  end
end
