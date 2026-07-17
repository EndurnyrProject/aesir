defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ElementalChange do
  @moduledoc """
  Elemental Change (SC_ELEMENTALCHANGE).

  Overrides the carrier's *defense* element only -- never the attack element.
  rAthena keeps the two calculations entirely separate: `status_calc_element`
  and `status_calc_element_lv` (defense element/level) consult
  `SC_ELEMENTALCHANGE`, while `status_calc_attack_element` does not
  (`status.cpp:8761-8817` vs `status.cpp:8836-8862`). A mob endowed with this
  status still attacks with its native weapon element.

  Mob-only: applied by the four `SA_ELEMENT*` converter skills (Task 24).
  `val1` holds the element level (1-4), `val2` the rAthena element id,
  mirroring `sc_start2`'s `(skill_lv, skill_get_ele(...))` argument order in
  `elementalchangewater.cpp:22-24`.

  `StatusStorage.apply_status/4` replaces the existing entry when a status of
  the same type is re-applied to a unit (single ETS row keyed by
  `{unit_type, unit_id, status_type}`), so a second converter skill landing on
  an already-overridden mob swaps the element cleanly instead of stacking --
  `ModifierCalculator.merge_modifiers/2` never sees two `:element_override`
  values to sum.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_elementalchange,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:def_ele],
    icon: :armor_property

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
    element = Map.fetch!(@elements, instance.val2)
    %{element_override: {element, cap_level(instance.val1)}}
  end

  @spec cap_level(integer()) :: 1..4
  defp cap_level(level), do: level |> max(1) |> min(4)
end
