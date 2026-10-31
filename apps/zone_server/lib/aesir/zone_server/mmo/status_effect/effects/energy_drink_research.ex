defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnergyDrinkResearch do
  @moduledoc """
  SP Increase Potion's item-stage maximum-SP percentage, identical in both modes.

  `val1` selects the holder's level (1) or the thrower's level (2), and `val2`
  is the potion size (1–3). A fresh application stores
  `max(div(level, 10) + 5 * size - 10, 0)` in `val3`; a saved status retains
  that amount. Only players consume this separate item-percentage stage.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_energy_drink_reserch,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [:max_sp_item_rate],
    icon: :energy_drink_reserch

  @impl true
  def on_apply(_target, instance, %{loaded: true}), do: {:ok, instance}

  def on_apply(_target, %{val1: kind} = instance, context) when kind in [1, 2] do
    stats = if kind == 2 and context.caster != %{}, do: context.caster, else: context.target
    bonus = max(div(stats.base_level, 10) + 5 * instance.val2 - 10, 0)
    {:ok, %{instance | val3: bonus}}
  end

  def on_apply(_target, instance, _context), do: {:ok, %{instance | val3: max(instance.val3, 0)}}

  @impl true
  def modifiers(instance, %{unit_type: :player}), do: %{max_sp_item_rate: instance.val3}
  def modifiers(_instance, _context), do: %{}
end
