defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WatkElement do
  @moduledoc """
  Weapon Element Endow (SC_WATK_ELEMENT).

  Overrides the carrier's physical attack element for the buff duration.
  Mirrors rAthena, where `val1` holds the element id used as the attack
  element in `battle_attr_fix`. Here `val1` is the rAthena element id and is
  mapped to the codebase's element atom, exposed via the `attack_element`
  modifier that the damage calculator prefers over the weapon's base element.

  Every endow contributes that same modifier and aggregation sums colliding
  keys, so the endows list each other in `end_on_start` (replace-on-cast) to
  keep two of them from ever being live at once.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_watk_element,
    no_dispel: false,
    properties: [:buff],
    end_on_start: [
      :sc_aspersio,
      :sc_encpoison,
      :sc_fireweapon,
      :sc_waterweapon,
      :sc_windweapon,
      :sc_earthweapon
    ],
    no_save: true

  alias Aesir.ZoneServer.Mmo.Element

  @impl true
  def modifiers(instance, _context) do
    %{attack_element: Element.from_id!(instance.val1)}
  end
end
