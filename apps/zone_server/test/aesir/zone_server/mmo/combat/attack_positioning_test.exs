defmodule Aesir.ZoneServer.Mmo.Combat.AttackPositioningTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.AttackPositioning

  test "approaches the adjoining cell along the target vector" do
    open = fn _, _ -> true end
    assert AttackPositioning.adjacent_attack_cell({5, 10}, {10, 10}, open) == {9, 10}
    assert AttackPositioning.adjacent_attack_cell({5, 5}, {10, 10}, open) == {9, 9}
  end

  test "a blocked approach tries adjoining cells in direction order" do
    walkable = fn x, y -> {x, y} != {9, 10} end
    assert AttackPositioning.adjacent_attack_cell({5, 10}, {10, 10}, walkable) == {10, 9}
  end

  test "refuses a target with no traversable adjoining cell" do
    assert AttackPositioning.adjacent_attack_cell({5, 10}, {10, 10}, fn _, _ -> false end) == nil
  end

  test "sharing the target cell does not force a step away" do
    assert AttackPositioning.adjacent_attack_cell({10, 10}, {10, 10}, fn _, _ -> true end) ==
             {10, 10}
  end
end
