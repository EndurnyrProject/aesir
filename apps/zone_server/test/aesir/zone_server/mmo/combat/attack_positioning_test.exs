defmodule Aesir.ZoneServer.Mmo.Combat.AttackPositioningTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.AttackPositioning

  defp walkable, do: fn _x, _y -> true end
  defp free, do: fn _x, _y -> false end

  describe "adjacent_attack_cell/5" do
    test "melee range 1 returns a cell adjacent to the target, never the target cell" do
      cell = AttackPositioning.adjacent_attack_cell({5, 10}, {10, 10}, 1, walkable(), free())

      assert cell != {10, 10}
      {x, y} = cell
      assert abs(x - 10) <= 1 and abs(y - 10) <= 1
    end

    test "returns the valid candidate closest to the attacker along the approach vector" do
      assert AttackPositioning.adjacent_attack_cell({5, 10}, {10, 10}, 1, walkable(), free()) ==
               {9, 10}

      assert AttackPositioning.adjacent_attack_cell({5, 5}, {10, 10}, 1, walkable(), free()) ==
               {9, 9}
    end

    test "skips an occupied candidate in favor of the next-best adjacent cell" do
      occupied = fn x, y -> {x, y} == {9, 10} end

      assert AttackPositioning.adjacent_attack_cell({5, 10}, {10, 10}, 1, walkable(), occupied) ==
               {9, 9}
    end

    test "returns nil when all in-range cells are blocked or occupied" do
      blocked = fn _x, _y -> false end

      assert AttackPositioning.adjacent_attack_cell({5, 10}, {10, 10}, 1, blocked, free()) == nil

      all_occupied = fn _x, _y -> true end

      assert AttackPositioning.adjacent_attack_cell(
               {5, 10},
               {10, 10},
               1,
               walkable(),
               all_occupied
             ) ==
               nil
    end
  end
end
