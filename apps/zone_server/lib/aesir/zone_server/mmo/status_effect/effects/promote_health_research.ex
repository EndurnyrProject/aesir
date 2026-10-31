defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PromoteHealthResearch do
  @moduledoc """
  HP Increase Potion's fixed maximum-HP bonus, identical in both modes.

  `val1` selects the holder's level (1) or the thrower's level (2), and `val2`
  is the potion size (1–3). A fresh application stores
  `max(1000 * size - 500 + div(level * 10, 3), 0)` in `val3`. Restoring a
  saved status preserves that computed amount instead of using a new level.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_promote_health_reserch,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [:max_hp],
    icon: :promote_health_reserch

  @impl true
  def on_apply(_target, instance, %{loaded: true}), do: {:ok, instance}

  def on_apply(_target, %{val1: kind} = instance, context) when kind in [1, 2] do
    stats = if kind == 2 and context.caster != %{}, do: context.caster, else: context.target
    bonus = max(1_000 * instance.val2 - 500 + div(stats.base_level * 10, 3), 0)
    {:ok, %{instance | val3: bonus}}
  end

  def on_apply(_target, instance, _context), do: {:ok, %{instance | val3: max(instance.val3, 0)}}

  @impl true
  def modifiers(instance, _context), do: %{max_hp: instance.val3}
end
