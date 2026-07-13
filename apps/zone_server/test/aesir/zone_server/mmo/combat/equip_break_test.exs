defmodule Aesir.ZoneServer.Mmo.Combat.EquipBreakTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers

  setup :setup_ets_tables
  setup :verify_on_exit!

  # Real equip.yml ids covering the weapon-type break rule.
  @sword 1101
  @mace 1340

  # Deterministic rolls (rng returns the value; a slot breaks when roll <= rate).
  defp best_roll, do: fn _ -> 1 end
  defp worst_roll, do: fn n -> n end

  defp attacker(equipment_mods \\ %{}, right_hand \\ @sword) do
    %Stats{
      equipment: %Equipment{right_hand: right_hand},
      modifiers: %Modifiers{equipment: equipment_mods}
    }
  end

  defp victim(equipment_mods \\ %{}, right_hand \\ @sword) do
    %Stats{
      equipment: %Equipment{right_hand: right_hand},
      modifiers: %Modifiers{equipment: equipment_mods}
    }
  end

  describe "rate boundaries" do
    test "a zero rate never breaks (best possible roll)" do
      attacker = attacker(%{break_weapon_rate: 0, break_armor_rate: 0})

      assert EquipBreak.resolve(attacker, {:player, victim()}, rng: best_roll()) == []
    end

    test "a 10000 rate always breaks (worst possible roll)" do
      attacker = attacker(%{break_weapon_rate: 10_000, break_armor_rate: 10_000})

      assert EquipBreak.resolve(attacker, {:player, victim()}, rng: worst_roll()) == [
               {:target, :weapon},
               {:target, :armor}
             ]
    end
  end

  describe "break prevention" do
    test "a per-slot unbreakable_weapon masks the weapon slot without a roll" do
      attacker = attacker(%{break_weapon_rate: 10_000, break_armor_rate: 10_000})
      victim = victim(%{unbreakable_weapon: 1})

      assert EquipBreak.resolve(attacker, {:player, victim}, rng: best_roll()) == [
               {:target, :armor}
             ]
    end

    test "a per-slot unbreakable_armor masks the armor slot without a roll" do
      attacker = attacker(%{break_weapon_rate: 10_000, break_armor_rate: 10_000})
      victim = victim(%{unbreakable_armor: 1})

      assert EquipBreak.resolve(attacker, {:player, victim}, rng: best_roll()) == [
               {:target, :weapon}
             ]
    end

    test "percentage unbreakable reduces the effective rate" do
      attacker = attacker(%{break_armor_rate: 100})
      roll_75 = fn _ -> 75 end

      # Without prevention the effective rate is 100 and the roll of 75 breaks it.
      assert EquipBreak.resolve(attacker, {:player, victim()}, rng: roll_75) == [
               {:target, :armor}
             ]

      # A 50% unbreakable halves the rate to 50; the same roll of 75 no longer breaks.
      protected = victim(%{unbreakable: 50})
      assert EquipBreak.resolve(attacker, {:player, protected}, rng: roll_75) == []
    end
  end

  describe "weapon-type immunity" do
    test "the target's own weapon type gates the target break, not the attacker's" do
      # An immune-type attacker (mace) still breaks a breakable-weapon target
      # (sword); armor break is unaffected by weapon type.
      attacker = attacker(%{break_weapon_rate: 10_000, break_armor_rate: 10_000}, @mace)

      assert EquipBreak.resolve(attacker, {:player, victim(%{}, @sword)}, rng: worst_roll()) == [
               {:target, :weapon},
               {:target, :armor}
             ]
    end

    test "an immune-type target never suffers a weapon break from a breakable attacker" do
      # A breakable-weapon attacker (sword) cannot break an immune-type target
      # (mace); armor break is still allowed.
      attacker = attacker(%{break_weapon_rate: 10_000, break_armor_rate: 10_000}, @sword)

      assert EquipBreak.resolve(attacker, {:player, victim(%{}, @mace)}, rng: worst_roll()) == [
               {:target, :armor}
             ]
    end
  end

  describe "non-player victim" do
    test "emits no :target decisions against a mob" do
      attacker = attacker(%{break_weapon_rate: 10_000, break_armor_rate: 10_000})

      assert EquipBreak.resolve(attacker, {:mob, nil}, rng: best_roll()) == []
    end

    test "self decisions still apply against a mob" do
      stub(Config, :natural_break_rate, fn -> 10_000 end)
      attacker = attacker(%{break_weapon_rate: 10_000, break_armor_rate: 10_000})

      assert EquipBreak.resolve(attacker, {:mob, nil}, rng: worst_roll()) == [{:self, :weapon}]
    end
  end

  describe "self weapon natural break" do
    test "derives from Config.natural_break_rate" do
      stub(Config, :natural_break_rate, fn -> 10_000 end)

      assert EquipBreak.resolve(attacker(), {:mob, nil}, rng: worst_roll()) == [{:self, :weapon}]
    end

    test "a natural break rate of 0 never breaks the own weapon" do
      stub(Config, :natural_break_rate, fn -> 0 end)

      assert EquipBreak.resolve(attacker(), {:mob, nil}, rng: best_roll()) == []
    end

    test "a mace attacker never suffers a natural weapon break" do
      stub(Config, :natural_break_rate, fn -> 10_000 end)

      assert EquipBreak.resolve(attacker(%{}, @mace), {:mob, nil}, rng: worst_roll()) == []
    end

    test "the attacker's own unbreakable_weapon prevents the natural break" do
      stub(Config, :natural_break_rate, fn -> 10_000 end)
      attacker = attacker(%{unbreakable_weapon: 1})

      assert EquipBreak.resolve(attacker, {:mob, nil}, rng: best_roll()) == []
    end
  end
end
