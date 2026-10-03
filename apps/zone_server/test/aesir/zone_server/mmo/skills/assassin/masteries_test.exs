defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.MasteriesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsKatar
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsLeft
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsRight

  test "Righthand Mastery supplies the canonical dual-wield rate" do
    assert AsRight.right_hand_damage_rate(1, %{}) == 60
    assert AsRight.right_hand_damage_rate(5, %{}) == 100
  end

  test "Lefthand Mastery supplies the canonical dual-wield rate" do
    assert AsLeft.left_hand_damage_rate(1, %{}) == 40
    assert AsLeft.left_hand_damage_rate(5, %{}) == 80
  end

  test "Katar Mastery grants ATK only while wielding a Katar" do
    assert AsKatar.atk_bonus(1, %{weapon_type: :katar}) == 3
    assert AsKatar.atk_bonus(10, %{weapon_type: :katar}) == 30
    assert AsKatar.atk_bonus(10, %{weapon_type: :dagger}) == 0
  end
end
