defmodule Aesir.ZoneServer.Mmo.Combat.SpDrainTest do
  use ExUnit.Case, async: false
  use Mimic

  :code.unstick_mod(:rand)
  Mimic.copy(:rand)

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.SpDrain

  defp attacker(modifiers) do
    %{CombatTestHelper.create_player_combatant() | equip_modifiers: modifiers}
  end

  defp defender(race) do
    %{CombatTestHelper.create_mob_combatant() | race: race}
  end

  describe "roll/2" do
    test "restores the flat value without a percentage drain" do
      attacker = attacker(%{sp_drain_value: 7})

      assert SpDrain.roll(attacker, 400) == 7
    end

    test "adds matching and all-race flat drain values" do
      attacker =
        attacker(%{
          :sp_drain_value => 2,
          {:sp_drain_race, :undead} => 5,
          {:sp_drain_race, :all} => 3
        })

      assert SpDrain.roll(attacker, 400) + SpDrain.race_value(attacker, defender(:undead)) == 10
      assert SpDrain.roll(attacker, 400) + SpDrain.race_value(attacker, defender(:brute)) == 5
    end

    test "adds the percentage drain after a successful roll" do
      attacker = attacker(%{sp_drain_value: 7, sp_drain_rate: 500, sp_drain_percent: 5})
      stub(:rand, :uniform, fn 1_000 -> 500 end)

      assert SpDrain.roll(attacker, 400) == 27
    end

    test "keeps only the flat value after a failed roll" do
      attacker = attacker(%{sp_drain_value: 7, sp_drain_rate: 500, sp_drain_percent: 5})
      stub(:rand, :uniform, fn 1_000 -> 501 end)

      assert SpDrain.roll(attacker, 400) == 7
    end

    test "returns zero for non-positive damage or absent drain keys" do
      attacker = attacker(%{sp_drain_value: 7, sp_drain_rate: 1_000, sp_drain_percent: 100})

      assert SpDrain.roll(attacker, 0) == 0
      assert SpDrain.roll(attacker, -50) == 0
      assert SpDrain.roll(attacker(%{}), 400) == 0
    end
  end
end
