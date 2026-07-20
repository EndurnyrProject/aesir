defmodule Aesir.ZoneServer.Mmo.Skills.PrMacemasteryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.PrMacemastery

  test "grants 3 ATK and 10 internal critical tenths per level while wielding a mace" do
    assert PrMacemastery.atk_bonus(1, %{weapon_type: :mace}) == 3
    assert PrMacemastery.atk_bonus(10, %{weapon_type: :mace}) == 30
    assert PrMacemastery.critical_bonus(1, %{weapon_type: :mace}) == 10
    assert PrMacemastery.critical_bonus(5, %{weapon_type: :mace}) == 50
    assert PrMacemastery.critical_bonus(10, %{weapon_type: :mace}) == 100
  end

  test "grants the same bonuses while wielding a two-handed mace" do
    assert PrMacemastery.atk_bonus(10, %{weapon_type: :two_handed_mace}) == 30
    assert PrMacemastery.critical_bonus(10, %{weapon_type: :two_handed_mace}) == 100
  end

  test "grants no bonuses with other weapons" do
    assert PrMacemastery.atk_bonus(10, %{weapon_type: :staff}) == 0
    assert PrMacemastery.critical_bonus(10, %{weapon_type: :staff}) == 0
  end

  test "is discovered as skill id 65 with maximum level 10" do
    assert {:ok, definition} = Catalog.by_id(65)
    assert definition.name == :pr_macemastery
    assert definition.max_level == 10
  end
end
