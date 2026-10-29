defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WatkElementTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.WatkElement

  @tag game_mode: :pre_renewal
  test "a percentage turns part of the attack into that element instead of overriding it" do
    assert WatkElement.modifiers(%{val1: 3, val2: 20}, %{}) == %{
             {:pseudo_element_atk, :fire} => 20
           }
  end

  @tag game_mode: :renewal
  test "renewal makes the percentage a weapon ATK rate, not an elemental share" do
    assert WatkElement.modifiers(%{val1: 3, val2: 20}, %{}) == %{watk_element_rate: 20}
  end
end
