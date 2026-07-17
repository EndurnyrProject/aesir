defmodule Aesir.ZoneServer.Mmo.Skills.SaAdvancedbookTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.SaAdvancedbook

  test "skill_name/0" do
    assert SaAdvancedbook.skill_name() == :sa_advancedbook
  end

  test "atk_bonus is 3 * level with a book" do
    assert SaAdvancedbook.atk_bonus(1, %{weapon_type: :book}) == 3
    assert SaAdvancedbook.atk_bonus(10, %{weapon_type: :book}) == 30
  end

  test "atk_bonus is 0 with any other weapon" do
    assert SaAdvancedbook.atk_bonus(10, %{weapon_type: :staff}) == 0
    assert SaAdvancedbook.atk_bonus(10, %{weapon_type: :fist}) == 0
  end

  test "aspd_bonus is (level - 1) / 2 + 1 with a book" do
    assert SaAdvancedbook.aspd_bonus(1, %{weapon_type: :book}) == 1
    assert SaAdvancedbook.aspd_bonus(2, %{weapon_type: :book}) == 1
    assert SaAdvancedbook.aspd_bonus(5, %{weapon_type: :book}) == 3
    assert SaAdvancedbook.aspd_bonus(10, %{weapon_type: :book}) == 5
  end

  test "aspd_bonus is 0 with any other weapon" do
    assert SaAdvancedbook.aspd_bonus(10, %{weapon_type: :staff}) == 0
  end
end
