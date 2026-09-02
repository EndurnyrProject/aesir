defmodule Aesir.ZoneServer.Mmo.Combat.MagicDefenseTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.MagicDefense
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "reflected magic hits land without rolling again" do
    defender =
      CombatTestHelper.create_player_combatant()
      |> Map.put(:equip_modifiers, %{no_magic_damage: 100, magic_damage_return: 100})

    roll = fn _chance -> flunk("reflected hits must not roll") end

    assert MagicDefense.resolve(defender, %{reflected: true, from_caster?: true}, roll) == :hit
  end

  test "full immunity misses before the reflection roll" do
    defender =
      CombatTestHelper.create_player_combatant()
      |> Map.put(:equip_modifiers, %{no_magic_damage: 120, magic_damage_return: 100})

    roll = fn _chance -> flunk("full immunity must not roll") end

    assert MagicDefense.resolve(defender, %{from_caster?: true}, roll) == :miss
  end

  test "ground magic hits land without rolling for reflection" do
    defender =
      CombatTestHelper.create_player_combatant()
      |> Map.put(:equip_modifiers, %{magic_damage_return: 100})

    roll = fn _chance -> flunk("ground hits must not roll") end

    assert MagicDefense.resolve(defender, %{from_caster?: false}, roll) == :hit
  end

  test "successful equipment roll reflects from-caster magic" do
    defender =
      CombatTestHelper.create_player_combatant()
      |> Map.put(:equip_modifiers, %{magic_damage_return: 35})

    assert MagicDefense.resolve(defender, %{from_caster?: true}, &(&1 == 35)) == :reflect
  end

  test "the default roll reflects a one-hundred-percent chance" do
    defender =
      CombatTestHelper.create_player_combatant()
      |> Map.put(:equip_modifiers, %{magic_damage_return: 100})

    assert MagicDefense.resolve(defender, %{from_caster?: true}) == :reflect
  end

  test "an unsuccessful equipment roll leaves the hit unchanged" do
    defender =
      CombatTestHelper.create_player_combatant()
      |> Map.put(:equip_modifiers, %{magic_damage_return: 35})

    assert MagicDefense.resolve(defender, %{from_caster?: true}, fn _chance -> false end) == :hit
  end

  test "magic damage reduction clamps below zero and above one hundred" do
    assert MagicDefense.reduction_percent(%{no_magic_damage: -20}) == 0
    assert MagicDefense.reduction_percent(%{no_magic_damage: 120}) == 100
    assert MagicDefense.reduction_percent(%{}) == 0
  end

  test "subtracts the truncated reduction from uneven damage" do
    register_player(1_140, %{no_magic_damage: 40})

    assert MagicDefense.reduce(101, :player, 1_140) == 61
  end

  test "does not erase damage when the proportional reduction truncates to zero" do
    register_player(1_150, %{no_magic_damage: 50})

    assert MagicDefense.reduce(1, :player, 1_150) == 1
  end

  test "complete reduction still zeroes damage" do
    register_player(1_200, %{no_magic_damage: 100})

    assert MagicDefense.reduce(101, :player, 1_200) == 0
  end

  test "magic status immunity begins at fifty percent" do
    for {target_id, percent, expected} <- [
          {1_049, 49, false},
          {1_050, 50, true},
          {1_100, 100, true}
        ] do
      register_player(target_id, %{no_magic_damage: percent})
      assert MagicDefense.immune?({:player, target_id}) == expected
    end
  end

  test "missing players and players without modifiers have zero reduction" do
    assert MagicDefense.reduce(100, :player, 1_200) == 100
    refute MagicDefense.immune?({:player, 1_200})

    register_player(1_201, %{})

    assert MagicDefense.reduce(100, :player, 1_201) == 100
    refute MagicDefense.immune?({:player, 1_201})
  end

  test "mob defenders have no equipment magic defense" do
    mob = CombatTestHelper.create_mob_combatant()

    assert MagicDefense.resolve(mob, %{from_caster?: true}, fn chance -> chance > 0 end) == :hit
    assert MagicDefense.reduce(100, :mob, mob.unit_id) == 100
    refute MagicDefense.immune?({:mob, mob.unit_id})
  end

  test "full immunity is pure over the defender combatant" do
    defender = CombatTestHelper.create_player_combatant()

    refute MagicDefense.full_immunity?(%{defender | equip_modifiers: %{no_magic_damage: 99}})
    assert MagicDefense.full_immunity?(%{defender | equip_modifiers: %{no_magic_damage: 100}})
    assert MagicDefense.full_immunity?(%{defender | equip_modifiers: %{no_magic_damage: 120}})
  end

  defp register_player(target_id, equip_modifiers) do
    player =
      PlayerStateFixture.build(%{
        character_id: target_id,
        account_id: target_id,
        stats: %{
          combat_stats: %CombatStats{},
          modifiers: %{equipment: equip_modifiers}
        }
      })

    UnitRegistry.register_player(player, self())
  end
end
