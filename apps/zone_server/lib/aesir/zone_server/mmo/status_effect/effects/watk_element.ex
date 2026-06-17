defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WatkElement do
  @moduledoc """
  Weapon Element Endow (SC_WATK_ELEMENT).

  Overrides the carrier's physical attack element for the buff duration.
  Mirrors rAthena, where `val1` holds the element id used as the attack
  element in `battle_attr_fix`. Here `val1` is the rAthena element id and is
  mapped to the codebase's element atom, exposed via the `attack_element`
  modifier that the damage calculator prefers over the weapon's base element.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_watk_element,
    properties: [:buff]

  @elements %{
    0 => :neutral,
    1 => :water,
    2 => :earth,
    3 => :fire,
    4 => :wind,
    5 => :poison,
    6 => :holy,
    7 => :shadow,
    8 => :ghost,
    9 => :undead
  }

  @impl true
  def modifiers(instance, _context) do
    %{attack_element: Map.fetch!(@elements, instance.val1)}
  end
end
