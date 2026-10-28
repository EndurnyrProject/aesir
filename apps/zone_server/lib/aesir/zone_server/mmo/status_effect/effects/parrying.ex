defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Parrying do
  @moduledoc """
  Parrying (SC_PARRYING) stops 20 + 3 × level percent of the weapon hits that
  connect on the holder for damage, in both Renewal and pre-renewal, while
  wielding a two-handed sword. It rolls in `absorb_damage/4` as the last
  blocker of the damage stage, after Guard, so the hit roll, the damage
  calculation and the earlier blockers run first and a missed swing never
  rolls a parry. Magic and miscellaneous hits pass through, as does Cart
  Termination. `ignore_auto_guard` bypasses Guard only; Parrying still rolls.

  A parried hit deals nothing; the post-parry attack delay is not modelled.
  The existing guard visual is reused because there is no distinct parry
  effect id.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_parrying,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    no_save: true,
    properties: [:buff],
    require_weapon: [:two_handed_sword],
    target_types: [:player],
    icon: :parrying

  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.SpecialEffect

  @cart_termination 485

  @impl true
  def absorb_damage(target, %StatusEntry{val1: level} = entry, %{dmg_type: :physical} = hit, _ctx) do
    if Map.get(hit, :skill_id) != @cart_termination and
         :rand.uniform(100) <= 20 + 3 * min(max(level, 1), 10) do
      SpecialEffect.play(target, :guard, :area)
      {:ok, 0, entry}
    else
      {:ok, hit.damage, entry}
    end
  end

  def absorb_damage(_target, entry, %{damage: damage}, _context), do: {:ok, damage, entry}
end
