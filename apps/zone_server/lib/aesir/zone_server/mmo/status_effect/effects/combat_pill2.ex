defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CombatPill2 do
  @moduledoc """
  HE Combat Pill buff (SC_COMBAT_PILL2).

  As `SC_COMBAT_PILL` but with a steeper 5% max HP / max SP malus
  (`db/re/status.yml`: `bAtkRate`/`bMatkRate, getstatus(SC_COMBAT_PILL2,1)` plus
  literal `bMaxHPrate,-5`/`bMaxSPrate,-5`). Mixed magnitude: the rates are
  val1-driven, the maluses fixed.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_combat_pill2,
    properties: [:buff],
    calc_flags: [:atk_rate, :matk_rate, :max_hp_rate, :max_sp_rate],
    icon: :gm_battle2

  @impl true
  def modifiers(instance, _context) do
    val1 = instance.val1

    %{
      atk_rate: val1,
      matk_rate: val1,
      max_hp_rate: -5,
      max_sp_rate: -5
    }
  end
end
