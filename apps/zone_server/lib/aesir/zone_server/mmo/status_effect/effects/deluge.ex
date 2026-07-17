defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Deluge do
  @moduledoc """
  Deluge (SC_DELUGE), the water field buff left by Sage's SA_DELUGE.

  Applies to every unit standing on the field. In renewal the bonus is
  unconditional: unlike pre-renewal, the holder's defense element no longer
  gates it (`status.cpp:11019-11033`).

  Raises max HP by a tabulated percent (`status.cpp:3204-3205`) and the
  holder's water-element attack ratio by a tabulated number of percentage
  points (`battle.cpp:545-551`).

  ## Accepted deviation

  The max-HP bonus only reaches players. Aesir's `:max_hp_rate` modifier is read
  by the player stat recalc (`unit/player/stats.ex`), whereas a mob's max HP is
  static in `MobState` and never recalculated from status modifiers. rAthena
  applies `status_get_hpbonus` to mobs as well, so a mob standing in Deluge is
  missing its HP bonus here. The element ratio, which is the field's combat-
  relevant half, applies to every unit type. Revisit if mob max HP ever becomes
  recalculable.
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
