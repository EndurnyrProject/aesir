defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CombatPill do
  @moduledoc """
  Combat Pill buff (SC_COMBAT_PILL).

  Adds `val1` percent to both physical and magical damage while shaving 3% off
  max HP and max SP (`db/re/status.yml`: `bAtkRate`/`bMatkRate,
  getstatus(SC_COMBAT_PILL,1)` plus literal `bMaxHPrate,-3`/`bMaxSPrate,-3`).
  Mixed magnitude: the rates are val1-driven, the maluses fixed. The `atk_rate`/
  `matk_rate` deltas are consumed in the combat calculators; the negative
  `max_hp_rate`/`max_sp_rate` deltas in `unit/player/stats.ex`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_combat_pill,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:atk_rate, :matk_rate, :max_hp_rate, :max_sp_rate],
    icon: :gm_battle

  @impl true
  def modifiers(instance, _context) do
    val1 = instance.val1

    %{
      atk_rate: val1,
      matk_rate: val1,
      max_hp_rate: -3,
      max_sp_rate: -3
    }
  end
end
