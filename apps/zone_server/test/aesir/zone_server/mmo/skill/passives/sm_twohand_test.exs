defmodule Aesir.ZoneServer.Mmo.Skill.Passives.SmTwohandTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Passives.SmTwohand

  test "skill_name/0" do
    assert SmTwohand.skill_name() == :sm_twohand
  end

  test "atk_bonus is 4 * lvl for two-handed sword" do
    assert SmTwohand.atk_bonus(5, %{weapon_type: :two_handed_sword}) == 20
  end

  test "atk_bonus is 0 for other weapons" do
    assert SmTwohand.atk_bonus(5, %{weapon_type: :one_handed_sword}) == 0
    assert SmTwohand.atk_bonus(5, %{weapon_type: :dagger}) == 0
    assert SmTwohand.atk_bonus(5, %{weapon_type: :bow}) == 0
  end
end
