defmodule Aesir.ZoneServer.Mmo.Mechanics.SizesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Mechanics.Sizes.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.Sizes.Renewal

  test "knuckles and whips take their mode's size cells" do
    # rAthena db/re/size_fix.yml against db/pre-re/size_fix.yml.
    for {weapon_type, renewal, classic} <- [
          {:knuckle, {100, 100, 75}, {100, 75, 50}},
          {:whip, {75, 100, 75}, {75, 100, 50}}
        ] do
      assert cells(Renewal, weapon_type) == renewal
      assert cells(PreRenewal, weapon_type) == classic
    end
  end

  test "mounted spears use their large-target modifier against medium targets in both modes" do
    for implementation <- [Renewal, PreRenewal],
        weapon_type <- [:one_handed_spear, :two_handed_spear] do
      assert implementation.get_modifier(weapon_type, :medium, true) == 100
      assert implementation.get_modifier(weapon_type, :medium, false) == 75
    end
  end

  test "riding does not change non-medium or non-spear cells" do
    for implementation <- [Renewal, PreRenewal] do
      assert implementation.get_modifier(:one_handed_spear, :small, true) == 75
      assert implementation.get_modifier(:two_handed_spear, :large, true) == 100
      assert implementation.get_modifier(:dagger, :medium, true) == 75
    end
  end

  test "unknown weapon types remain neutral at every supported size" do
    for implementation <- [Renewal, PreRenewal], target_size <- [:small, :medium, :large] do
      assert implementation.get_modifier(:unknown_weapon, target_size, false) == 100
      assert implementation.get_modifier(:shield, target_size, true) == 100
    end
  end

  test "unsupported target sizes retain the function-clause failure" do
    for implementation <- [Renewal, PreRenewal] do
      assert_raise FunctionClauseError, fn ->
        implementation.get_modifier(:dagger, :invalid, false)
      end
    end
  end

  defp cells(implementation, weapon_type) do
    {implementation.get_modifier(weapon_type, :small, false),
     implementation.get_modifier(weapon_type, :medium, false),
     implementation.get_modifier(weapon_type, :large, false)}
  end
end
