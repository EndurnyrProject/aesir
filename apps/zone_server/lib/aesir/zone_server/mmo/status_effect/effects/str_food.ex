defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StrFood do
  @moduledoc """
  Food STR buff (SC_STRFOOD).

  Raises STR by `val1` for the duration. In rAthena both the magnitude and the
  duration come from the consumed item's `sc_start` (typically 20 min, +1..+10);
  the buff is a plain additive stat bonus with no other side effects.
  """
  # NOTE: Deferred food-buff semantics (applies to every SC_*FOOD in this dir):
  #   rAthena flags NoDispell/NoClearbuff/NoBanishingBuster/NoClearance +
  #   remove-on-death. Aesir has no dispel/clearbuff/clear-on-death mechanic
  #   yet, so foods currently persist like any other buff. When those land,
  #   foods must survive dispel/clearbuff but end on death.
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_strfood,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:str],
    icon: :food_str,
    end_on_start: [:sc_food_str_cash]

  @impl true
  def modifiers(instance, _context), do: %{str: instance.val1}
end
