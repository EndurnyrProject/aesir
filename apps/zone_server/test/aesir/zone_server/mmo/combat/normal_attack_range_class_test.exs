defmodule Aesir.ZoneServer.Mmo.Combat.NormalAttackRangeClassTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.WeaponTypes

  test "range_class_test" do
    for weapon <- [:bow, :revolver, :rifle, :gatling, :shotgun, :grenade] do
      assert WeaponTypes.long_range_attack?(weapon)
      assert WeaponTypes.long_range_attack?(WeaponTypes.get_weapon_id(weapon))
    end

    for weapon <- [:whip, :musical, :dagger] do
      refute WeaponTypes.long_range_attack?(weapon)
      refute WeaponTypes.long_range_attack?(WeaponTypes.get_weapon_id(weapon))
    end
  end
end
