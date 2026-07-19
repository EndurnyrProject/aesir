defmodule Aesir.ZoneServer.Mmo.Combat.HpDrainTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.HpDrain

  defp attacker(modifiers) do
    %{CombatTestHelper.create_player_combatant() | equip_modifiers: modifiers}
  end

  describe "roll/2" do
    test "recovers the drain percent of the damage when the roll always succeeds" do
      attacker = attacker(%{hp_drain_rate: 1_000, hp_drain_percent: 5})

      assert HpDrain.roll(attacker, 400) == 20
    end

    test "never drains at a zero rate" do
      attacker = attacker(%{hp_drain_rate: 0, hp_drain_percent: 100})

      assert Enum.uniq(for _ <- 1..200, do: HpDrain.roll(attacker, 500)) == [0]
    end

    test "never drains without a drain percent" do
      attacker = attacker(%{hp_drain_rate: 1_000, hp_drain_percent: 0})

      assert Enum.uniq(for _ <- 1..200, do: HpDrain.roll(attacker, 500)) == [0]
    end

    test "a zero-damage hit drains nothing even at a guaranteed rate" do
      attacker = attacker(%{hp_drain_rate: 1_000, hp_drain_percent: 100})

      assert HpDrain.roll(attacker, 0) == 0
      assert HpDrain.roll(attacker, -50) == 0
    end

    test "a mob carries no equipment, so it never drains" do
      mob = CombatTestHelper.create_mob_combatant()

      assert mob.equip_modifiers == %{}
      assert Enum.uniq(for _ <- 1..200, do: HpDrain.roll(mob, 500)) == [0]
    end

    test "rolls the rate against a per-mille scale" do
      attacker = attacker(%{hp_drain_rate: 500, hp_drain_percent: 100})

      drained = Enum.count(1..2_000, fn _ -> HpDrain.roll(attacker, 100) > 0 end)

      assert drained > 800
      assert drained < 1_200
    end

    test "a drain smaller than one HP recovers nothing" do
      attacker = attacker(%{hp_drain_rate: 1_000, hp_drain_percent: 1})

      assert HpDrain.roll(attacker, 50) == 0
    end
  end
end
