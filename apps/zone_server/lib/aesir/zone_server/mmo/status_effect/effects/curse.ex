defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Curse do
  @moduledoc """
  Curse (SC_CURSE).

  Drops LUK to 0, reduces ATK by 25% and slows movement. rAthena's
  `status_calc_speed` applies a flat `max(val, 300)` speed-rate penalty for
  curse, modelled here as `movement_speed: 300` (positive = slower). Targets
  whose LUK is already 0 are unaffected (rAthena behavior).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_curse,
    no_dispel: false,
    properties: [:debuff],
    calc_flags: [:luk, :atk, :speed],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_curse, :sc_protection],
    opt2: :curse

  @impl true
  def modifiers(_instance, _context) do
    %{luk: 0, atk_rate: -25, movement_speed: 300}
  end

  @impl true
  def on_apply(_target, instance, context) do
    if context.target.luk == 0 do
      :remove
    else
      {:ok, instance}
    end
  end
end
