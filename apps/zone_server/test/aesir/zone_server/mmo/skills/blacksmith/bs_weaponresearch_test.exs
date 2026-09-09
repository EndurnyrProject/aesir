defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsWeaponresearchTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsWeaponresearch

  @tag game_mode: :renewal
  test "renewal grants ATK and a hit-rate multiplier but no flat HIT" do
    assert BsWeaponresearch.atk_bonus(10, %{}) == 20
    assert BsWeaponresearch.hit_rate_bonus_pct(10, %{}) == 20
    assert BsWeaponresearch.hit_bonus(10, %{}) == 0
  end

  @tag game_mode: :pre_renewal
  test "classic adds a flat 2 HIT per level on top" do
    assert BsWeaponresearch.atk_bonus(10, %{}) == 20
    assert BsWeaponresearch.hit_rate_bonus_pct(10, %{}) == 20
    assert BsWeaponresearch.hit_bonus(10, %{}) == 20
  end
end
