defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adjustment do
  @moduledoc """
  Adjustment (SC_ADJUSTMENT). Lasts 30 s, trades 30 HIT for 30 FLEE and ends
  Madness Canceller when it starts. In the common damage stage, after Defending
  Aura and before Blinding Mist, a long-range weapon hit on the holder loses
  `damage * 20 / 100` (the removed amount is truncated). Same in both modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_adjustment,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [:hit, :flee],
    flags: [:no_banishing_buster],
    end_on_start: [:sc_madnesscancel],
    duration: 30_000,
    icon: :gs_adjustment

  @impl true
  def modifiers(_instance, _context), do: %{hit: -30, flee: 30}

  @impl true
  def absorb_damage(_target, instance, %{damage: damage} = hit, _context) do
    case hit do
      %{dmg_type: :physical, is_short: false} -> {:ok, damage - div(damage * 20, 100), instance}
      _other -> {:ok, damage, instance}
    end
  end
end
