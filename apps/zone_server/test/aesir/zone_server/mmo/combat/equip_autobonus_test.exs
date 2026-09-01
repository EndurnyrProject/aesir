defmodule Aesir.ZoneServer.Mmo.Combat.EquipAutobonusTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutobonus

  test "on_attack treats a stored zero flag as wildcard and skips ineligible rolls" do
    key = {11, 0}
    battle_flag = BattleFlags.build(:weapon, :short, false)
    parent = self()

    registrations = %{
      key => %{trigger: :attack, battle_flag: 0, rate: 1_000, source_order: {0, 0}},
      {12, 0} => %{
        trigger: :attack,
        battle_flag: BattleFlags.build(:magic, :long, true),
        rate: 1_000,
        source_order: {1, 0}
      },
      {13, 0} => %{
        trigger: :when_hit,
        battle_flag: battle_flag,
        rate: 1_000,
        source_order: {2, 0}
      }
    }

    assert [^key] =
             EquipAutobonus.on_attack(registrations, battle_flag,
               roll: fn rate ->
                 send(parent, {:rolled, rate})
                 true
               end
             )

    assert_received {:rolled, 1_000}
    refute_received {:rolled, _rate}
  end

  test "when_hit returns only when-hit registrations with matching flags" do
    key = {11, 0}
    battle_flag = BattleFlags.build(:weapon, :short, false)

    registrations = %{
      key => %{trigger: :when_hit, battle_flag: battle_flag, rate: 1_000, source_order: {0, 0}},
      {12, 0} => %{
        trigger: :when_hit,
        battle_flag: BattleFlags.build(:magic, :long, true),
        rate: 1_000,
        source_order: {1, 0}
      },
      {13, 0} => %{
        trigger: :attack,
        battle_flag: battle_flag,
        rate: 1_000,
        source_order: {2, 0}
      }
    }

    assert [^key] = EquipAutobonus.when_hit(registrations, battle_flag, roll: fn _ -> true end)
  end

  test "on_skill returns only registrations for the triggering skill" do
    key = {11, 0}

    registrations = %{
      key => %{trigger: {:on_skill, 42}, rate: 1_000, source_order: {0, 0}},
      {12, 0} => %{trigger: {:on_skill, 99}, rate: 1_000, source_order: {1, 0}},
      {13, 0} => %{trigger: :attack, battle_flag: 0, rate: 1_000, source_order: {2, 0}},
      {14, 0} => %{
        trigger: :when_hit,
        battle_flag: 0,
        rate: 1_000,
        source_order: {3, 0}
      }
    }

    assert [^key] = EquipAutobonus.on_skill(registrations, 42, roll: fn _ -> true end)
  end

  test "does not roll registrations clamped to zero" do
    battle_flag = BattleFlags.build(:weapon, :short, false)
    parent = self()

    registrations = %{
      {11, 0} => %{trigger: :attack, battle_flag: battle_flag, rate: -1, source_order: {0, 0}},
      {12, 0} => %{trigger: :attack, battle_flag: battle_flag, rate: 0, source_order: {1, 0}}
    }

    assert [] =
             EquipAutobonus.on_attack(registrations, battle_flag,
               roll: fn rate -> send(parent, {:rolled, rate}) end
             )

    refute_received {:rolled, _rate}
  end

  test "clamps rate boundaries and honors independent roll outcomes" do
    battle_flag = BattleFlags.build(:weapon, :short, false)
    parent = self()

    registrations = %{
      {11, 0} => %{trigger: :attack, battle_flag: battle_flag, rate: 1, source_order: {0, 0}},
      {12, 0} => %{
        trigger: :attack,
        battle_flag: battle_flag,
        rate: 1_000,
        source_order: {1, 0}
      },
      {13, 0} => %{
        trigger: :attack,
        battle_flag: battle_flag,
        rate: 2_000,
        source_order: {2, 0}
      }
    }

    send(parent, {:roll_outcome, false})
    send(parent, {:roll_outcome, true})
    send(parent, {:roll_outcome, true})

    assert [{12, 0}, {13, 0}] =
             EquipAutobonus.on_attack(registrations, battle_flag,
               roll: fn rate ->
                 send(parent, {:rolled, rate})

                 receive do
                   {:roll_outcome, outcome} -> outcome
                 end
               end
             )

    assert_received {:rolled, 1}
    assert_received {:rolled, 1_000}
    assert_received {:rolled, 1_000}
  end

  test "returns keys in explicit source order rather than key order" do
    battle_flag = BattleFlags.build(:weapon, :short, false)

    registrations = %{
      {30, 0} => %{trigger: :attack, battle_flag: battle_flag, rate: 1_000, source_order: {0, 0}},
      {20, 0} => %{trigger: :attack, battle_flag: battle_flag, rate: 1_000, source_order: {1, 0}},
      {99, 0} => %{trigger: :attack, battle_flag: battle_flag, rate: 1_000, source_order: {2, 0}}
    }

    assert [{30, 0}, {20, 0}, {99, 0}] =
             EquipAutobonus.on_attack(registrations, battle_flag, roll: fn _ -> true end)
  end

  test "returns no keys for an empty registration map" do
    assert [] = EquipAutobonus.on_attack(%{}, 0, roll: fn _ -> flunk("should not roll") end)
    assert [] = EquipAutobonus.when_hit(%{}, 0, roll: fn _ -> flunk("should not roll") end)
    assert [] = EquipAutobonus.on_skill(%{}, 42, roll: fn _ -> flunk("should not roll") end)
  end
end
