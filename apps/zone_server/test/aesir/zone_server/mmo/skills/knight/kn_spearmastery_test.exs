defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnSpearmasteryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnSpearmastery

  test "grants 4 ATK per level on foot with a one-handed spear" do
    assert KnSpearmastery.atk_bonus(1, %{weapon_type: :one_handed_spear, riding: false}) == 4
    assert KnSpearmastery.atk_bonus(10, %{weapon_type: :one_handed_spear, riding: false}) == 40
  end

  test "grants the same bonus on foot with a two-handed spear" do
    assert KnSpearmastery.atk_bonus(10, %{weapon_type: :two_handed_spear, riding: false}) == 40
  end

  test "grants 5 ATK per level while riding" do
    assert KnSpearmastery.atk_bonus(1, %{weapon_type: :one_handed_spear, riding: true}) == 5
    assert KnSpearmastery.atk_bonus(10, %{weapon_type: :one_handed_spear, riding: true}) == 50
    assert KnSpearmastery.atk_bonus(10, %{weapon_type: :two_handed_spear, riding: true}) == 50
  end

  test "grants no bonus with other weapons, mounted or not" do
    assert KnSpearmastery.atk_bonus(10, %{weapon_type: :one_handed_sword, riding: false}) == 0
    assert KnSpearmastery.atk_bonus(10, %{weapon_type: :one_handed_sword, riding: true}) == 0
  end

  test "is discovered as skill id 55 with maximum level 10" do
    assert {:ok, definition} = Catalog.by_id(55)
    assert definition.name == :kn_spearmastery
    assert definition.max_level == 10
  end
end
