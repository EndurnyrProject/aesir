defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McInccarryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Merchant.McInccarry

  test "skill_name/0" do
    assert McInccarry.skill_name() == :mc_inccarry
  end

  test "max_weight_bonus returns 2000 per skill level" do
    assert McInccarry.max_weight_bonus(10, %{}) == 20_000
    assert McInccarry.max_weight_bonus(5, %{}) == 10_000
  end
end
