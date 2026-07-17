defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.UltimateCook do
  @moduledoc """
  Ultimate Cook buff (SC_ULTIMATECOOK).

  Raises every base stat by `val1` and adds a fixed +30 ATK / +30 MATK
  (`db/re/status.yml`: `val1` per stat plus literal `bBaseAtk,30`/`bMatk,30`).
  Duration comes from the consumed item's `sc_start`. Starting it ends all six
  cash-food buffs and the overlapping Almighty buff (`EndOnStart`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_ultimatecook,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:str, :agi, :vit, :int, :dex, :luk, :atk, :matk],
    icon: :ultimatecook,
    end_on_start: [
      :sc_food_str_cash,
      :sc_food_agi_cash,
      :sc_food_vit_cash,
      :sc_food_int_cash,
      :sc_food_dex_cash,
      :sc_food_luk_cash,
      :sc_almighty
    ]

  @impl true
  def modifiers(instance, _context) do
    val1 = instance.val1

    %{
      str: val1,
      agi: val1,
      vit: val1,
      int: val1,
      dex: val1,
      luk: val1,
      atk: 30,
      matk: 30
    }
  end
end
