defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcOwlTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Archer.AcOwl

  test "skill_name/0" do
    assert AcOwl.skill_name() == :ac_owl
  end

  test "dex_bonus returns the skill level" do
    assert AcOwl.dex_bonus(1, %{}) == 1
    assert AcOwl.dex_bonus(7, %{}) == 7
    assert AcOwl.dex_bonus(10, %{}) == 10
  end
end
