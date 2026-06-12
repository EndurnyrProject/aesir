defmodule Aesir.ZoneServer.Mmo.StatusEffects.Freeze do
  @moduledoc """
  Freeze (SC_FREEZE).

  Frozen solid: water element body, halved DEF and increased MDEF. Undead are
  immune. Applying it ends Lex Aeterna.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_freeze,
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    calc_flags: [:def_ele, :def_rate, :mdef_rate],
    flags: [:no_move, :no_attack, :no_skill],
    end_on_start: [:sc_aeterna],
    prevented_by: [
      :sc_refresh,
      :sc_inspiration,
      :sc_warmer,
      :sc_freeze,
      :sc_burning,
      :sc_protection
    ],
    immunity: [:undead]

  @impl true
  def modifiers(_instance, _context) do
    %{def_ele: :water1, def_rate: -50, mdef_rate: 25}
  end
end
