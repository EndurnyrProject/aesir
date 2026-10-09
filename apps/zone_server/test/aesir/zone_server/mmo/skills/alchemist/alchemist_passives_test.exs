defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AlchemistPassivesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmAxemastery

  test "Axe Mastery grants 3 ATK per level with a one-handed axe" do
    assert AmAxemastery.atk_bonus(1, %{weapon_type: :one_handed_axe}) == 3
    assert AmAxemastery.atk_bonus(10, %{weapon_type: :one_handed_axe}) == 30
  end

  test "Axe Mastery grants 3 ATK per level with a two-handed axe" do
    assert AmAxemastery.atk_bonus(10, %{weapon_type: :two_handed_axe}) == 30
  end

  @tag game_mode: :renewal
  test "Axe Mastery grants 3 ATK per level with a one-handed sword" do
    assert AmAxemastery.atk_bonus(10, %{weapon_type: :one_handed_sword}) == 30
  end

  @tag game_mode: :pre_renewal
  test "classic Axe Mastery grants no ATK with a one-handed sword" do
    assert AmAxemastery.atk_bonus(10, %{weapon_type: :one_handed_sword}) == 0
  end

  test "Axe Mastery grants no ATK without a supported weapon" do
    assert AmAxemastery.atk_bonus(10, %{weapon_type: :mace}) == 0
    assert AmAxemastery.atk_bonus(10, %{weapon_type: :bare_hands}) == 0
  end
end
