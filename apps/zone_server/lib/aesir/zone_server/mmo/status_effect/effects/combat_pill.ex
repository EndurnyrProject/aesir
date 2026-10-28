defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CombatPill do
  @moduledoc """
  Combat Pill buff (SC_COMBAT_PILL).

  Grants the item-script ATK rate (`bonus_atk_rate`: `val1` percent of weapon
  and equipment ATK, renewal only) and MATK rate (`matk_rate`) while shaving 3%
  off max HP and max SP. Mixed magnitude: the rates are val1-driven, the
  maluses fixed.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_combat_pill,
    remove_on_death: false,
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    calc_flags: [:atk, :matk_rate, :max_hp_rate, :max_sp_rate],
    icon: :gm_battle

  @impl true
  def modifiers(instance, _context) do
    val1 = instance.val1

    %{
      bonus_atk_rate: val1,
      matk_rate: val1,
      max_hp_rate: -3,
      max_sp_rate: -3
    }
  end
end
