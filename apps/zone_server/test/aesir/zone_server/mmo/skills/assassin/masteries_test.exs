defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.MasteriesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsKatar
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsLeft
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsRight

  test "Righthand Mastery supplies the canonical dual-wield rate" do
    assert %{id: 132, name: :as_right, max_level: 5, target_type: :passive} = AsRight.definition()
    assert AsRight.right_hand_damage_rate(1, %{}) == 60
    assert AsRight.right_hand_damage_rate(5, %{}) == 100
  end

  test "Lefthand Mastery supplies the canonical dual-wield rate" do
    assert %{id: 133, name: :as_left, max_level: 5, target_type: :passive} = AsLeft.definition()
    assert AsLeft.left_hand_damage_rate(1, %{}) == 40
    assert AsLeft.left_hand_damage_rate(5, %{}) == 80
  end

  test "Katar Mastery grants ATK only while wielding a Katar" do
    assert %{id: 134, name: :as_katar, max_level: 10, target_type: :passive} =
             AsKatar.definition()

    assert AsKatar.atk_bonus(1, %{weapon_type: :katar}) == 3
    assert AsKatar.atk_bonus(10, %{weapon_type: :katar}) == 30
    assert AsKatar.atk_bonus(10, %{weapon_type: :dagger}) == 0
  end
end
