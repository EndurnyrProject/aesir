defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoDodgeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoDodge

  test "grants floor(1.5 times level) FLEE" do
    assert MoDodge.flee_bonus(1, %{}) == 1
    assert MoDodge.flee_bonus(3, %{}) == 4
    assert MoDodge.flee_bonus(10, %{}) == 15
  end
end
