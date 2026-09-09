defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SubWeaponPropertyTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SubWeaponProperty
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry, as: StatusRegistry

  test "turns a percentage of the attack into its element without overriding it" do
    assert SubWeaponProperty.modifiers(%{val1: 3, val2: 20}, %{}) == %{
             {:pseudo_element_atk, :fire} => 20
           }

    assert SubWeaponProperty.modifiers(%{val1: 1, val2: 5}, %{}) == %{
             {:pseudo_element_atk, :water} => 5
           }
  end

  test "never overrides the carrier's attack element" do
    refute Map.has_key?(SubWeaponProperty.modifiers(%{val1: 3, val2: 20}, %{}), :attack_element)
  end

  test "neither cancels nor is cancelled by the weapon endows" do
    definition = StatusRegistry.get_definition(:sc_sub_weaponproperty)

    assert definition.end_on_start == []

    for endow <- [
          :sc_aspersio,
          :sc_encpoison,
          :sc_fireweapon,
          :sc_waterweapon,
          :sc_windweapon,
          :sc_earthweapon,
          :sc_watk_element
        ] do
      refute :sc_sub_weaponproperty in StatusRegistry.get_definition(endow).end_on_start
    end
  end
end
