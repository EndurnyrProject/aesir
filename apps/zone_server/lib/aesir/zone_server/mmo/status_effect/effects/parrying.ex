defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Parrying do
  @moduledoc """
  Parrying (SC_PARRYING) intercepts 20 + 3 × level percent of incoming weapon hits
  in both Renewal and pre-renewal, while wielding a two-handed sword. Magic and
  miscellaneous attacks never reach the weapon-hit hook.

  Cart Termination's bypass and a post-parry attack delay are not modelled.
  `:ignores_auto_guard` bypasses Auto Guard only; Parrying still rolls. The
  existing guard visual is reused because there is no distinct parry effect id.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_parrying,
    no_dispel: false,
    no_save: true,
    properties: [:buff],
    require_weapon: [:two_handed_sword],
    target_types: [:player],
    icon: :parrying

  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.SpecialEffect

  @impl true
  def before_weapon_hit(target, %StatusEntry{val1: level}, _attack_info, _context) do
    if :rand.uniform(100) <= 20 + 3 * min(max(level, 1), 10) do
      SpecialEffect.play(target, :guard, :area)
      {:intercept, :blocked}
    else
      :continue
    end
  end
end
