defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ViolentGale do
  @moduledoc """
  Violent Gale (SC_VIOLENTGALE), the wind field buff left by Sage's
  SA_VIOLENTGALE.

  Applies to every unit standing on the field. In renewal the bonus is
  unconditional: unlike pre-renewal, the holder's defense element no longer
  gates it (`status.cpp:11008-11018`).

  Raises flee by `3 * level` (`status.cpp:7637-7638`) and the holder's
  wind-element attack ratio by a tabulated number of percentage points
  (`battle.cpp:538-544`).

  ## Accepted deviation

  The flee bonus only reaches players. Aesir's `:flee` modifier is read by the
  player flee recalc (`unit/player/combat_calculations.ex`), whereas a mob's
  flee is `level + agi` with no status term. rAthena's `status_calc_flee`
  covers mobs too, so a mob standing in Violent Gale is missing its flee bonus
  here. The element ratio applies to every unit type.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_violentgale,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:flee],
    no_save: true,
    icon: :groundmagic

  alias Aesir.ZoneServer.Mmo.StatusEffect.FieldElement

  @impl true
  def modifiers(instance, _context) do
    level = instance.val1

    %{
      :flee => 3 * level,
      {:element_ratio, :wind} => FieldElement.enchant_bonus(level)
    }
  end
end
