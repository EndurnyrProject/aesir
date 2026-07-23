defmodule Aesir.ZoneServer.Mmo.Combat.SizeModifiersTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers

  # weapon_type => {small, medium, large}
  @table %{
    fist: {100, 100, 100},
    dagger: {100, 75, 50},
    one_handed_sword: {75, 100, 75},
    two_handed_sword: {75, 75, 100},
    one_handed_spear: {75, 75, 100},
    two_handed_spear: {75, 75, 100},
    one_handed_axe: {50, 75, 100},
    two_handed_axe: {50, 75, 100},
    mace: {75, 100, 100},
    two_handed_mace: {100, 100, 100},
    staff: {100, 100, 100},
    two_handed_staff: {100, 100, 100},
    bow: {100, 100, 75},
    musical: {75, 100, 75},
    whip: {75, 100, 75},
    book: {100, 100, 50},
    katar: {75, 100, 75},
    knuckle: {100, 100, 75},
    revolver: {100, 100, 100},
    rifle: {100, 100, 100},
    gatling: {100, 100, 100},
    shotgun: {100, 100, 100},
    grenade: {100, 100, 100},
    huuma: {100, 100, 100}
  }

  describe "get_modifier/3 table" do
    for {weapon_type, {small, medium, large}} <- @table do
      test "#{weapon_type} vs small is #{small}" do
        assert SizeModifiers.get_modifier(unquote(weapon_type), :small) == unquote(small)
      end

      test "#{weapon_type} vs medium is #{medium}" do
        assert SizeModifiers.get_modifier(unquote(weapon_type), :medium) == unquote(medium)
      end

      test "#{weapon_type} vs large is #{large}" do
        assert SizeModifiers.get_modifier(unquote(weapon_type), :large) == unquote(large)
      end
    end
  end

  describe "riding override" do
    test "one_handed_spear vs medium becomes the large modifier while riding" do
      assert SizeModifiers.get_modifier(:one_handed_spear, :medium, true) == 100
    end

    test "two_handed_spear vs medium becomes the large modifier while riding" do
      assert SizeModifiers.get_modifier(:two_handed_spear, :medium, true) == 100
    end

    test "spears vs small/large are unaffected by riding" do
      assert SizeModifiers.get_modifier(:one_handed_spear, :small, true) == 75
      assert SizeModifiers.get_modifier(:one_handed_spear, :large, true) == 100
      assert SizeModifiers.get_modifier(:two_handed_spear, :small, true) == 75
      assert SizeModifiers.get_modifier(:two_handed_spear, :large, true) == 100
    end

    test "non-spear weapons are unaffected by riding" do
      assert SizeModifiers.get_modifier(:one_handed_sword, :medium, true) == 100
      assert SizeModifiers.get_modifier(:dagger, :medium, true) == 75
      assert SizeModifiers.get_modifier(:bow, :medium, true) == 100
    end

    test "riding defaults to false when omitted" do
      assert SizeModifiers.get_modifier(:one_handed_spear, :medium) == 75
    end
  end

  describe "unknown weapon type" do
    test "falls back to 100 at every size" do
      assert SizeModifiers.get_modifier(:unknown_weapon, :small) == 100
      assert SizeModifiers.get_modifier(:unknown_weapon, :medium) == 100
      assert SizeModifiers.get_modifier(:unknown_weapon, :large) == 100
    end
  end
end
