defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaDragonologyTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaDragonology

  test "skill_name/0" do
    assert SaDragonology.skill_name() == :sa_dragonology
  end

  test "int_bonus is (level + 1) / 2" do
    assert SaDragonology.int_bonus(1, %{}) == 1
    assert SaDragonology.int_bonus(2, %{}) == 1
    assert SaDragonology.int_bonus(5, %{}) == 3
  end
end
