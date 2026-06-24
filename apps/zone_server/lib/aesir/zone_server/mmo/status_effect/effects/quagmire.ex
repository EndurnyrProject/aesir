defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Quagmire do
  @moduledoc """
  Quagmire (SC_QUAGMIRE).

  Reduces AGI and DEX (val2), slows attack and movement speed, and strips
  active speed buffs when applied.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_quagmire,
    properties: [:debuff],
    calc_flags: [:agi, :dex, :aspd, :speed],
    end_on_start: [
      :sc_loud,
      :sc_concentrate,
      :sc_truesight,
      :sc_windwalk,
      :sc_magneticfield,
      :sc_cartboost,
      :sc_gn_cartboost,
      :sc_increaseagi,
      :sc_adrenaline,
      :sc_adrenaline2,
      :sc_spearquicken,
      :sc_twohandquicken,
      :sc_onehand,
      :sc_merc_quicken,
      :sc_acceleration
    ],
    conflicts_with: [:sc_speedup1],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :quagmire

  @impl true
  def modifiers(instance, _context) do
    %{
      agi: -instance.val2,
      dex: -instance.val2,
      aspd: instance.val2,
      movement_speed: 50
    }
  end
end
