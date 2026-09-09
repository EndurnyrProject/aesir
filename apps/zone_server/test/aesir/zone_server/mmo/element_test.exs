defmodule Aesir.ZoneServer.Mmo.ElementTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Element
  alias Aesir.ZoneServer.Mmo.Mechanics.Elements.PreRenewal
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ElementalChange
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.WatkElement

  test "unknown elements support a caller-selected fallback without aliasing neutral" do
    assert Element.id(:unknown) == 0
    assert Element.id(:unknown, nil) == nil
    assert Element.id(:neutral, nil) == 0
  end

  test "unknown numeric IDs remain errors in both status consumers" do
    for id <- [-1, 10, nil, 1.0, "1"] do
      assert_raise KeyError, fn -> Element.from_id!(id) end
      assert_raise KeyError, fn -> ElementalChange.modifiers(%{val1: 1, val2: id}, %{}) end
      assert_raise KeyError, fn -> WatkElement.modifiers(%{val1: id}, %{}) end
    end
  end

  test "classic formulas distinguish unknown elements from neutral interactions" do
    assert PreRenewal.get_modifier(:neutral, :ghost, 1, 0) == 0.25
    assert PreRenewal.get_modifier(:unknown, :ghost, 1, 0) == 1.0
    assert PreRenewal.get_modifier(:ghost, :unknown, 1, 20) == 1.2
  end

  test "converts every combat element to and from its numeric ID" do
    elements = [
      {:neutral, 0},
      {:water, 1},
      {:earth, 2},
      {:fire, 3},
      {:wind, 4},
      {:poison, 5},
      {:holy, 6},
      {:shadow, 7},
      {:ghost, 8},
      {:undead, 9}
    ]

    for {element, id} <- elements do
      assert Element.id(element) == id
      assert Element.from_id!(id) == element
      assert ElementModifiers.id(element) == id
      assert WatkElement.modifiers(%{val1: id}, %{}) == %{attack_element: element}

      assert ElementalChange.modifiers(%{val1: 2, val2: id}, %{}) ==
               %{element_override: {element, 2}}
    end
  end
end
