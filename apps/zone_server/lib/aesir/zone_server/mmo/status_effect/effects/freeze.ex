defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Freeze do
  @moduledoc """
  Freeze (SC_FREEZE).

  Frozen solid: water element body, halved DEF and increased MDEF. Bosses,
  undead and units with freeze immunity are immune. Applying it ends Lex Aeterna.
  Any active damage breaks it.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_freeze,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    calc_flags: [:def_ele, :def_rate, :mdef_rate],
    flags: [:no_move, :no_attack, :no_skill, :remove_on_damaged],
    end_on_start: [:sc_aeterna],
    prevented_by: [
      renewal: [
        :sc_refresh,
        :sc_inspiration,
        :sc_warmer,
        :sc_gvg_freez,
        :sc_whiteimprison,
        :sc_stone,
        :sc_stonewait,
        :sc_freeze,
        :sc_stun,
        :sc_sleep,
        :sc_burning,
        :sc_protection
      ],
      pre_renewal: [
        :sc_refresh,
        :sc_inspiration,
        :sc_warmer,
        :sc_gvg_freez,
        :sc_stone,
        :sc_stonewait,
        :sc_freeze,
        :sc_stun,
        :sc_sleep,
        :sc_burning
      ]
    ],
    immunity: [:boss, :freeze, :undead],
    resistance_type: :magical,
    duration_adjustment: 3_000,
    opt1: :freeze

  @impl true
  def modifiers(_instance, _context) do
    %{element_override: {:water, 1}, def_rate: -50, mdef_rate: 25}
  end
end
