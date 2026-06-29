defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DecreaseAgi do
  @moduledoc """
  Decrease AGI (SC_DECREASEAGI).

  Lowers AGI by 2 + skill level (val1) and reduces movement speed, stripping
  active speed buffs when applied. rAthena's `status_calc_speed` applies a flat
  `max(val, 25)` slow regardless of skill level, modelled here as
  `movement_speed: 25` (positive = slower).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_decreaseagi,
    properties: [:debuff],
    calc_flags: [:agi, :speed],
    end_on_start: [
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
    icon: :dec_agi

  @impl true
  def modifiers(instance, _context) do
    %{
      agi: -(2 + instance.val1),
      movement_speed: 25
    }
  end
end
