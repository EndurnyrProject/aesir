defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoDodgeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoDodge

  test "grants floor(1.5 times level) FLEE" do
    assert MoDodge.flee_bonus(1, %{}) == 1
    assert MoDodge.flee_bonus(3, %{}) == 4
    assert MoDodge.flee_bonus(10, %{}) == 15
  end

  test "is discovered as passive skill id 265" do
    assert {:ok, definition} = Catalog.by_id(265)
    assert definition.name == :mo_dodge
    assert definition.max_level == 10
    assert definition.target_type == :passive
  end
end
