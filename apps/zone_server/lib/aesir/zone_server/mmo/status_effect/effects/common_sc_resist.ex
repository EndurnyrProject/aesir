defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CommonScResist do
  @moduledoc """
  Mega Resist Potion adds `val1` per ten thousand to the ten common ailments'
  equipment-style resistance, not percentage points of general status defense.

  Identical in both modes. Dispel cannot remove it; death and buff clearing can.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_commonsc_resist,
    target_types: [:player],
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    icon: :target_blood

  @ailments [
    :sc_stun,
    :sc_freeze,
    :sc_stonewait,
    :sc_curse,
    :sc_poison,
    :sc_silence,
    :sc_blind,
    :sc_sleep,
    :sc_bleeding,
    :sc_confusion
  ]

  @impl true
  def modifiers(instance, _context),
    do: Map.new(@ailments, &{{:res_eff, &1}, instance.val1})
end
