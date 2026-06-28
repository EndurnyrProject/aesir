defmodule Aesir.ZoneServer.Mmo.WeaponTypesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.WeaponTypes

  describe "get_attack_range/1" do
    test "returns correct range for melee weapons" do
      # Basic melee weapons have range 1
      assert WeaponTypes.get_attack_range(:fist) == 1
      assert WeaponTypes.get_attack_range(:dagger) == 1
      assert WeaponTypes.get_attack_range(:one_handed_sword) == 1
      assert WeaponTypes.get_attack_range(:two_handed_sword) == 1
      assert WeaponTypes.get_attack_range(:mace) == 1
      assert WeaponTypes.get_attack_range(:staff) == 1

      # Test with integer IDs
      # fist
      assert WeaponTypes.get_attack_range(0) == 1
      # dagger
      assert WeaponTypes.get_attack_range(1) == 1
      # one_handed_sword
      assert WeaponTypes.get_attack_range(2) == 1
      # mace
      assert WeaponTypes.get_attack_range(8) == 1
    end

    test "returns extended range for spears" do
      # Spears have range 2
      assert WeaponTypes.get_attack_range(:one_handed_spear) == 2
      assert WeaponTypes.get_attack_range(:two_handed_spear) == 2

      # Test with integer IDs
      # one_handed_spear
      assert WeaponTypes.get_attack_range(4) == 2
      # two_handed_spear
      assert WeaponTypes.get_attack_range(5) == 2
    end

    test "returns long range for ranged weapons" do
      # Ranged weapons have range 9
      assert WeaponTypes.get_attack_range(:bow) == 9
      assert WeaponTypes.get_attack_range(:musical) == 9
      assert WeaponTypes.get_attack_range(:whip) == 9
      assert WeaponTypes.get_attack_range(:revolver) == 9
      assert WeaponTypes.get_attack_range(:rifle) == 9
      assert WeaponTypes.get_attack_range(:gatling) == 9
      assert WeaponTypes.get_attack_range(:shotgun) == 9
      assert WeaponTypes.get_attack_range(:grenade) == 9

      # Test with integer IDs
      # bow
      assert WeaponTypes.get_attack_range(11) == 9
      # revolver
      assert WeaponTypes.get_attack_range(17) == 9
      # rifle
      assert WeaponTypes.get_attack_range(18) == 9
    end

    test "handles unknown weapon types" do
      # Unknown integer weapon ID should default to melee range
      assert WeaponTypes.get_attack_range(999) == 1
    end
  end

  describe "requires_ammo?/1" do
    test "returns true for ammo-consuming weapon atoms" do
      assert WeaponTypes.requires_ammo?(:bow)
      assert WeaponTypes.requires_ammo?(:revolver)
      assert WeaponTypes.requires_ammo?(:rifle)
      assert WeaponTypes.requires_ammo?(:gatling)
      assert WeaponTypes.requires_ammo?(:shotgun)
      assert WeaponTypes.requires_ammo?(:grenade)
    end

    test "returns true for ammo-consuming weapon integer ids" do
      # bow = 11
      assert WeaponTypes.requires_ammo?(11)
      # revolver = 17
      assert WeaponTypes.requires_ammo?(17)
      # rifle = 18
      assert WeaponTypes.requires_ammo?(18)
      # gatling = 19
      assert WeaponTypes.requires_ammo?(19)
      # shotgun = 20
      assert WeaponTypes.requires_ammo?(20)
      # grenade = 21
      assert WeaponTypes.requires_ammo?(21)
    end

    test "returns false for melee weapons" do
      refute WeaponTypes.requires_ammo?(:dagger)
      refute WeaponTypes.requires_ammo?(:staff)
      refute WeaponTypes.requires_ammo?(:fist)
      # integer ids
      refute WeaponTypes.requires_ammo?(1)
      refute WeaponTypes.requires_ammo?(10)
      refute WeaponTypes.requires_ammo?(0)
    end

    test "returns false for ranged weapons that do not use ammo" do
      refute WeaponTypes.requires_ammo?(:whip)
      refute WeaponTypes.requires_ammo?(:musical)
      # integer ids
      refute WeaponTypes.requires_ammo?(14)
      refute WeaponTypes.requires_ammo?(13)
    end
  end

  describe "integration with existing functions" do
    test "ranged weapons correctly identified as ranged and have long range" do
      ranged_weapons = [:bow, :musical, :whip, :revolver, :rifle, :gatling, :shotgun, :grenade]

      for weapon <- ranged_weapons do
        assert WeaponTypes.is_ranged?(weapon) == true
        assert WeaponTypes.get_attack_range(weapon) == 9
      end
    end

    test "spears are melee but have extended range" do
      spear_weapons = [:one_handed_spear, :two_handed_spear]

      for weapon <- spear_weapons do
        assert WeaponTypes.is_ranged?(weapon) == false
        assert WeaponTypes.get_attack_range(weapon) == 2
      end
    end
  end
end
