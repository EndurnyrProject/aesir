defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AlchemistPassivesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmAxemastery

  test "Axe Mastery grants 3 ATK per level with a one-handed axe" do
    assert AmAxemastery.atk_bonus(1, %{weapon_type: :one_handed_axe}) == 3
    assert AmAxemastery.atk_bonus(10, %{weapon_type: :one_handed_axe}) == 30
  end

  test "Axe Mastery grants 3 ATK per level with a two-handed axe" do
    assert AmAxemastery.atk_bonus(10, %{weapon_type: :two_handed_axe}) == 30
  end

  test "Axe Mastery grants 3 ATK per level with a one-handed sword" do
    assert AmAxemastery.atk_bonus(10, %{weapon_type: :one_handed_sword}) == 30
  end

  test "Axe Mastery grants no ATK without a supported weapon" do
    assert AmAxemastery.atk_bonus(10, %{weapon_type: :mace}) == 0
    assert AmAxemastery.atk_bonus(10, %{weapon_type: :bare_hands}) == 0
  end

  test "Alchemist passives are discovered by id" do
    assert {:ok, axe_mastery} = Catalog.by_id(226)
    assert axe_mastery.name == :am_axemastery
    assert axe_mastery.max_level == 10

    assert {:ok, learning_potion} = Catalog.by_id(227)
    assert learning_potion.name == :am_learningpotion
    assert learning_potion.max_level == 10
  end
end
