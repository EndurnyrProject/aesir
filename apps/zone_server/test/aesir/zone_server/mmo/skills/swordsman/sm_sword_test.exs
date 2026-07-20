defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmSwordTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmSword

  test "skill_name/0" do
    assert SmSword.skill_name() == :sm_sword
  end

  test "atk_bonus is 4 * lvl for one-handed sword and dagger" do
    assert SmSword.atk_bonus(5, %{weapon_type: :one_handed_sword}) == 20
    assert SmSword.atk_bonus(5, %{weapon_type: :dagger}) == 20
  end

  test "atk_bonus is 0 for other weapons" do
    assert SmSword.atk_bonus(5, %{weapon_type: :two_handed_sword}) == 0
    assert SmSword.atk_bonus(5, %{weapon_type: :bow}) == 0
  end
end
