defmodule Aesir.ZoneServer.Mmo.Mechanics.SizesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Mechanics.Sizes.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.Sizes.Renewal

  @renewal_table %{
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
    knuckle: {100, 100, 75},
    musical: {75, 100, 75},
    whip: {75, 100, 75},
    book: {100, 100, 50},
    katar: {75, 100, 75},
    revolver: {100, 100, 100},
    rifle: {100, 100, 100},
    gatling: {100, 100, 100},
    shotgun: {100, 100, 100},
    grenade: {100, 100, 100},
    huuma: {100, 100, 100}
  }

  @pre_renewal_table %{
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
    knuckle: {100, 75, 50},
    musical: {75, 100, 75},
    whip: {75, 100, 50},
    book: {100, 100, 50},
    katar: {75, 100, 75},
    revolver: {100, 100, 100},
    rifle: {100, 100, 100},
    gatling: {100, 100, 100},
    shotgun: {100, 100, 100},
    grenade: {100, 100, 100},
    huuma: {100, 100, 100}
  }

  test "renewal matches every canonical weapon and target-size cell" do
    assert_table(Renewal, @renewal_table)
  end

  test "pre-renewal matches every canonical weapon and target-size cell" do
    assert_table(PreRenewal, @pre_renewal_table)
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

  defp assert_table(implementation, table) do
    assert map_size(table) == 24

    for {weapon_type, {small, medium, large}} <- table do
      assert implementation.get_modifier(weapon_type, :small, false) == small
      assert implementation.get_modifier(weapon_type, :medium, false) == medium
      assert implementation.get_modifier(weapon_type, :large, false) == large
    end
  end
end
