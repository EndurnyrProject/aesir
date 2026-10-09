defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WatkElementTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.WatkElement

  test "a percentage turns part of the attack into that element instead of overriding it" do
    assert WatkElement.modifiers(%{val1: 3, val2: 20}, %{}) == %{
             {:pseudo_element_atk, :fire} => 20
           }
  end
end
