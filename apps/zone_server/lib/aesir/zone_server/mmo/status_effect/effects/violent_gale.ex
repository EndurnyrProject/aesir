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

  The `:flee` bonus reaches both unit types. A player picks it up through the
  flee recalc (`unit/player/combat_calculations.ex`); a mob folds every combat
  number — flee included — live in `MobState.to_combatant/1`, which sums the
  active `:flee` modifiers onto its base `level + agi`, matching rAthena's
  `status_calc_flee` covering `[PC|MOB|HOM|MER|ELEM]`. The element ratio applies
  to every unit type.
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
