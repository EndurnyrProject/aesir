defmodule Aesir.ZoneServer.Mmo.Combat.AtkPercentTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.AtkPercent

  @bash 5
  @asura 271
  @spiral_pierce 397

  test "sums the status rate over 100 for a normal attack and a mastery-stacking skill" do
    assert AtkPercent.percent(:player, nil, %{atk_rate: 30}) == 130
    assert AtkPercent.percent(:player, @bash, %{atk_rate: -25}) == 75
    assert AtkPercent.percent(:mob, @bash, %{}) == 100
    assert AtkPercent.delta(:player, @bash, %{atk_rate: 30}) == 30
  end

  test "a player's non-mastery-stacking skill takes 100; a monster's never does" do
    assert AtkPercent.percent(:player, @asura, %{atk_rate: 30}) == 100
    assert AtkPercent.percent(:mob, @asura, %{atk_rate: 30}) == 130
    assert AtkPercent.percent(:homunculus, @asura, %{atk_rate: 30}) == 130
  end

  test "caps the percent at 0 and 65535" do
    assert AtkPercent.percent(:mob, nil, %{atk_rate: -150}) == 0
    assert AtkPercent.percent(:mob, nil, %{atk_rate: 70_000}) == 65_535
    assert AtkPercent.delta(:mob, nil, %{atk_rate: -150}) == -100
  end

  @tag game_mode: :pre_renewal
  test "classic Spiral Pierce stacks only the refine and Star Crumb bonuses" do
    refute AtkPercent.stacks_masteries?(@spiral_pierce, :all)
    assert AtkPercent.stacks_masteries?(@spiral_pierce, :refine)
    assert AtkPercent.percent(:player, @spiral_pierce, %{atk_rate: 30}) == 100
  end

  @tag game_mode: :renewal
  test "renewal Spiral Pierce stacks everything" do
    assert AtkPercent.stacks_masteries?(@spiral_pierce, :all)
    assert AtkPercent.percent(:player, @spiral_pierce, %{atk_rate: 30}) == 130
  end
end
