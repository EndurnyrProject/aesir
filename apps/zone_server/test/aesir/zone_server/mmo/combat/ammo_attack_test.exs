defmodule Aesir.ZoneServer.Mmo.Combat.AmmoAttackTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.Renewal
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.Player.Stats.EquipmentFold

  setup :setup_ets_tables
  setup :set_mimic_private

  @tag game_mode: :pre_renewal
  test "ammo_atk_pre_re_variance_test" do
    attacker = attacker(:bow, :arrow)
    :rand.seed(:exsss, {11, 12, 13})

    damages =
      for _ <- 1..128 do
        parts = DamageInputs.player_attack_parts(attacker, [], :primary, false)
        PreRenewal.normal_base(parts, %{size_rate: 75}) - parts.status_atk
      end

    assert MapSet.new(damages) == MapSet.new(301..308)
    assert attacker.combat_stats.physical_attack.flat_atk == 0
  end

  @tag game_mode: :pre_renewal
  test "ammo_atk_crit_modes_test" do
    bow = attacker(:bow, :arrow)
    parts = DamageInputs.player_attack_parts(bow, [], :primary, true)

    assert parts.weapon_atk == 402
    assert parts.ammo_atk == 10
    assert PreRenewal.normal_base(parts, %{size_rate: 75}) - parts.status_atk == 309

    for weapon <- [:revolver, :rifle, :gatling, :shotgun, :grenade] do
      gun = attacker(weapon, :bullet)
      parts = DamageInputs.player_attack_parts(gun, [], :primary, true)

      assert parts.weapon_atk == 201
      assert parts.ammo_atk == 0
      assert PreRenewal.normal_base(parts, %{size_rate: 75}) - parts.status_atk == 150
    end
  end

  test "Bash with a revolver does not add ammunition ATK" do
    gun = attacker(:revolver, :bullet)
    empty = attacker(:revolver, :bullet, 0)
    defender = CombatTestHelper.create_mob_combatant(def: 0, soft_def: 0, element: {:neutral, 1})
    opts = [skill_id: 5, skill_ratio: 130]
    :rand.seed(:exsss, {11, 12, 13})

    for _ <- 1..32 do
      parts = DamageInputs.player_attack_parts(gun, opts, :primary, false)
      assert parts.ammo_atk == 0
      assert {:ok, result} = DamageCalculator.calculate_damage(gun, defender, opts)
      assert {:ok, baseline} = DamageCalculator.calculate_damage(empty, defender, opts)
      assert result.damage == baseline.damage
    end
  end

  test "Venom Knife with a dagger adds ammunition ATK only in renewal" do
    dagger = attacker(:dagger, :dagger)
    empty = attacker(:dagger, :dagger, 0)
    defender = CombatTestHelper.create_mob_combatant(def: 0, soft_def: 0, element: {:neutral, 1})
    opts = [skill_id: 1004, skill_ratio: if(GameMode.mode() == :renewal, do: 500, else: 100)]

    for {armed, unarmed} <- [
          {dagger, empty},
          {%{dagger | right_hand: nil, weapon: %{type: :fist}},
           %{empty | right_hand: nil, weapon: %{type: :fist}}}
        ] do
      parts = DamageInputs.player_attack_parts(armed, opts, :primary, false)

      assert parts.ammo_atk == if(GameMode.mode() == :renewal, do: 10, else: 0)
      assert {:ok, result} = DamageCalculator.calculate_damage(armed, defender, opts)
      assert {:ok, baseline} = DamageCalculator.calculate_damage(unarmed, defender, opts)
      assert result.damage - baseline.damage == if(GameMode.mode() == :renewal, do: 50, else: 0)
    end
  end

  test "ammo_atk_single_add_test" do
    gun = attacker(:revolver, :bullet)
    empty = attacker(:revolver, :bullet, 0)
    defender = CombatTestHelper.create_mob_combatant(def: 0, soft_def: 0, element: {:neutral, 1})
    opts = [skill_id: 46, skill_ratio: 150]
    assert {:ok, baseline} = DamageCalculator.calculate_damage(empty, defender, opts)
    assert baseline.damage == if(GameMode.mode() == :pre_renewal, do: 1502, else: 1218)
    :rand.seed(:exsss, {11, 12, 13})

    deltas =
      MapSet.new(
        for _ <- 1..128 do
          assert {:ok, result} = DamageCalculator.calculate_damage(gun, defender, opts)
          result.damage - baseline.damage
        end
      )

    expected =
      if GameMode.mode() == :pre_renewal,
        do: [0, 1, 3, 4, 6, 7, 9, 10, 12, 13],
        else: [15]

    assert deltas == MapSet.new(expected)
    assert gun.combat_stats.physical_attack.flat_atk == 0

    dagger = attacker(:dagger, :bullet)
    empty_dagger = attacker(:dagger, :bullet, 0)
    assert {:ok, result} = DamageCalculator.calculate_damage(dagger, defender, opts)
    assert {:ok, baseline} = DamageCalculator.calculate_damage(empty_dagger, defender, opts)
    assert result.damage == baseline.damage + if(GameMode.mode() == :renewal, do: 15, else: 0)
  end

  @tag game_mode: :renewal
  test "ammo_atk_renewal_equipment_test" do
    for weapon <- [:bow, :revolver], critical? <- [false, true] do
      attacker = attacker(weapon, :bullet)
      parts = DamageInputs.player_attack_parts(attacker, [], :primary, critical?)
      components = Renewal.prepare_components(parts, %{size_rate: 75})

      assert components.flat_atk == 10
      assert components.weapon_atk == div(parts.weapon_atk * 75, 100)
    end

    cannon = attacker(:revolver, :cannonball)
    parts = DamageInputs.player_attack_parts(cannon, [], :primary, false)
    assert Renewal.prepare_components(parts, %{size_rate: 75}).flat_atk == 0

    gun = attacker(:revolver, :bullet)
    empty = attacker(:revolver, :bullet, 0)
    defender = CombatTestHelper.create_mob_combatant(def: 0, soft_def: 0, element: {:water, 1})
    opts = [skill_id: 46, element: :fire]

    assert {:ok, result} = DamageCalculator.calculate_damage(gun, defender, opts)
    assert {:ok, baseline} = DamageCalculator.calculate_damage(empty, defender, opts)
    assert result.damage - baseline.damage == 9
  end

  defp attacker(weapon_type, ammo_type, ammo_atk \\ 10) do
    definitions = %{
      90_001 => %ItemDefinition{
        id: 90_001,
        aegis_name: "TestWeapon",
        name: "Test Weapon",
        type: :weapon,
        subtype: weapon_type,
        weapon_level: 1,
        attack: 201,
        range: 7
      },
      90_002 => %ItemDefinition{
        id: 90_002,
        aegis_name: "TestAmmo",
        name: "Test Ammo",
        type: :ammo,
        subtype: ammo_type,
        attack: ammo_atk
      }
    }

    stub(ItemManagement, :get_item_by_id, &Map.fetch(definitions, &1))

    state =
      PlayerState.new(%Character{
        id: 7_003,
        account_id: 7_003,
        name: "Ammo",
        last_map: "prontera",
        class: 0,
        sex: "M",
        dex: 200
      })

    stats =
      state.stats
      |> EquipmentFold.apply_equipment_modifiers([
        %InventoryItem{nameid: 90_001, amount: 1, equip: 2, identify: 1},
        %InventoryItem{nameid: 90_002, amount: 1, equip: 32_768, identify: 1}
      ])
      |> Calculator.calculate_combat_stats()

    combatant = PlayerState.to_combatant(%{state | stats: stats})
    put_in(combatant.combat_stats.max_weapon_damage, true)
  end
end
