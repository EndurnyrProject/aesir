defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Deluge do
  @moduledoc """
  Deluge (SC_DELUGE), the water field buff left by Sage's SA_DELUGE.

  Applies to every unit standing on the field. In renewal the bonus is
  unconditional: unlike pre-renewal, the holder's defense element no longer
  gates it (`status.cpp:11019-11033`).

  Raises max HP by a tabulated percent (`status.cpp:3204-3205`) and the
  holder's water-element attack ratio by a tabulated number of percentage
  points (`battle.cpp:545-551`).

  The `:max_hp_rate` bonus reaches both unit types. A player picks it up through
  the stat recalc (`unit/player/stats.ex`); a mob recomputes its stored HP
  ceiling via `MobState.recalculate_max_hp/1` whenever the status applies or
  ends, mirroring rAthena's non-PC `status_calc_maxhp` (`status.cpp:6213`,
  `status.cpp:8712`) — the buff raises the ceiling without healing, and its
  removal caps overflow HP back down. The element ratio applies to every unit
  type.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_deluge,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:max_hp_rate],
    no_save: true,
    icon: :groundmagic

  alias Aesir.ZoneServer.Mmo.StatusEffect.FieldElement

  @hp_rate {5, 9, 12, 14, 15}

  @impl true
  def modifiers(instance, _context) do
    level = instance.val1

    %{
      :max_hp_rate => elem(@hp_rate, max(rem(level - 1, 5), 0)),
      {:element_ratio, :water} => FieldElement.enchant_bonus(level)
    }
  end
end
