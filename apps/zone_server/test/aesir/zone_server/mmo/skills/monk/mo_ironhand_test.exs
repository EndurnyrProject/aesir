defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoIronhandTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoIronhand

  test "grants exactly 3 ATK per level while wielding a fist or knuckle" do
    assert MoIronhand.atk_bonus(1, %{weapon_type: :fist}) == 3
    assert MoIronhand.atk_bonus(10, %{weapon_type: :fist}) == 30
    assert MoIronhand.atk_bonus(10, %{weapon_type: :knuckle}) == 30
  end

  test "grants no ATK while wielding an unrelated weapon" do
    assert MoIronhand.atk_bonus(10, %{weapon_type: :mace}) == 0
  end
end
