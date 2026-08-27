defmodule Aesir.ZoneServer.Mmo.Combat.BattleFlagsTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias Aesir.ZoneServer.Mmo.AutoTriggerFlag
  alias Aesir.ZoneServer.Mmo.BattleFlag
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags

  defp battle(names), do: Enum.reduce(names, 0, &bor(BattleFlag.id(&1), &2))
  defp trigger(names), do: Enum.reduce(names, 0, &bor(AutoTriggerFlag.id(&1), &2))

  describe "build/3" do
    test "names all three axes of a hit" do
      assert BattleFlags.build(:weapon, :short, false) ==
               battle([:weapon, :short, :normal])

      assert BattleFlags.build(:magic, :long, true) == battle([:magic, :long, :skill])
    end
  end

  describe "fill_battle/1" do
    test "an unnamed range matches both distances" do
      assert BattleFlags.fill_battle(battle([:weapon, :normal])) ==
               battle([:weapon, :normal, :short, :long])
    end

    test "an unnamed damage type means weapon" do
      filled = BattleFlags.fill_battle(battle([:normal]))

      assert (filled &&& BattleFlag.id(:weapon)) != 0
    end

    test "a weapon bonus with no named origin covers normal swings and skills" do
      assert BattleFlags.fill_battle(battle([:weapon])) ==
               battle([:weapon, :short, :long, :normal, :skill])
    end

    test "a magic or misc bonus with no named origin is skill-only" do
      assert BattleFlags.fill_battle(battle([:magic])) ==
               battle([:magic, :short, :long, :skill])

      assert BattleFlags.fill_battle(battle([:misc])) ==
               battle([:misc, :short, :long, :skill])
    end

    test "a named origin is left alone" do
      assert BattleFlags.fill_battle(battle([:normal])) ==
               battle([:normal, :weapon, :short, :long])
    end
  end

  describe "fill_trigger/1" do
    test "fills range, victim and damage type" do
      assert BattleFlags.fill_trigger(trigger([:target])) ==
               trigger([:target, :short, :long, :weapon])

      assert BattleFlags.fill_trigger(trigger([:magic])) ==
               trigger([:magic, :short, :long, :target])
    end

    test "a named victim axis is left alone" do
      filled = BattleFlags.fill_trigger(trigger([:self]))

      assert (filled &&& AutoTriggerFlag.id(:self)) != 0
      assert (filled &&& AutoTriggerFlag.id(:target)) == 0
    end
  end

  describe "matches_battle?/2" do
    setup do
      %{
        melee_swing: BattleFlags.build(:weapon, :short, false),
        ranged_swing: BattleFlags.build(:weapon, :long, false),
        weapon_skill: BattleFlags.build(:weapon, :short, true),
        magic_skill: BattleFlags.build(:magic, :long, true)
      }
    end

    test "an unconditional bonus matches every attack", ctx do
      assert BattleFlags.matches_battle?(0, ctx.melee_swing)
      assert BattleFlags.matches_battle?(0, ctx.magic_skill)
    end

    test "the damage-type axis gates the match", ctx do
      magic_only = BattleFlags.fill_battle(battle([:magic]))

      assert BattleFlags.matches_battle?(magic_only, ctx.magic_skill)
      refute BattleFlags.matches_battle?(magic_only, ctx.melee_swing)
      refute BattleFlags.matches_battle?(magic_only, ctx.weapon_skill)
    end

    test "the range axis gates the match", ctx do
      short_weapon = BattleFlags.fill_battle(battle([:weapon, :short]))

      assert BattleFlags.matches_battle?(short_weapon, ctx.melee_swing)
      refute BattleFlags.matches_battle?(short_weapon, ctx.ranged_swing)
    end

    test "the origin axis separates normal swings from skills", ctx do
      normal_only = BattleFlags.fill_battle(battle([:weapon, :normal]))

      assert BattleFlags.matches_battle?(normal_only, ctx.melee_swing)
      refute BattleFlags.matches_battle?(normal_only, ctx.weapon_skill)
    end

    test "a weapon bonus covers both origins when none was named", ctx do
      weapon_any = BattleFlags.fill_battle(battle([:weapon]))

      assert BattleFlags.matches_battle?(weapon_any, ctx.melee_swing)
      assert BattleFlags.matches_battle?(weapon_any, ctx.weapon_skill)
    end
  end

  describe "matches_trigger?/2" do
    test "an entry naming every damage type imposes no type restriction" do
      any_type = BattleFlags.fill_trigger(trigger([:weapon, :magic, :misc]))

      assert BattleFlags.matches_trigger?(any_type, BattleFlags.build(:weapon, :short, false))
      assert BattleFlags.matches_trigger?(any_type, BattleFlags.build(:magic, :long, true))
    end

    test "a narrowed damage type gates the match" do
      magic_only = BattleFlags.fill_trigger(trigger([:magic]))

      assert BattleFlags.matches_trigger?(magic_only, BattleFlags.build(:magic, :long, true))
      refute BattleFlags.matches_trigger?(magic_only, BattleFlags.build(:weapon, :short, false))
    end

    test "a narrowed range gates the match" do
      short_only = BattleFlags.fill_trigger(trigger([:short]))

      assert BattleFlags.matches_trigger?(short_only, BattleFlags.build(:weapon, :short, false))
      refute BattleFlags.matches_trigger?(short_only, BattleFlags.build(:weapon, :long, false))
    end
  end

  describe "victim axis" do
    test "an unflagged bonus lands on the attack's other party" do
      assert BattleFlags.target_victim?(0)
      refute BattleFlags.self_victim?(0)
    end

    test "the bits select one or both victims" do
      target_only = BattleFlags.fill_trigger(trigger([:target]))
      self_only = BattleFlags.fill_trigger(trigger([:self]))
      both = BattleFlags.fill_trigger(trigger([:target, :self]))

      assert BattleFlags.target_victim?(target_only)
      refute BattleFlags.self_victim?(target_only)

      assert BattleFlags.self_victim?(self_only)
      refute BattleFlags.target_victim?(self_only)

      assert BattleFlags.target_victim?(both)
      assert BattleFlags.self_victim?(both)
    end
  end
end
