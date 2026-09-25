defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkSpiralpierceTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.LordKnight.LkSpiralpierce
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  @tag game_mode: :renewal
  test "Renewal level five uses spear weight, medium size, and base level" do
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)
    assert definition.id == 397
    caster = caster(1401)
    stub_weapon(1401, :one_handed_spear)
    assert :ok = LkSpiralpierce.validate(caster, {:unit, 6_160}, 5, definition)

    stub(Combat, :resolve_combatant, fn 6_160 ->
      {:ok, CombatTestHelper.create_mob_combatant(unit_id: 6_160, size: :medium)}
    end)

    expect(Combat, :execute_skill_attack, fn ^caster, 6_160, opts ->
      assert opts[:weight_atk] == 150
      assert opts[:base_atk_rate] == 80
      assert opts[:skill_ratio] == 396
      assert opts[:display_hit_count] == 5
      assert opts[:skip_crit] == true
      {:ok, %{hit?: false}}
    end)

    assert {:ok, ^caster} = LkSpiralpierce.cast(caster, {:unit, 6_160}, 5, definition)
  end

  @tag game_mode: :pre_renewal
  test "classic level five uses weapon weight and refine, bypassing defense and size" do
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)
    caster = caster(1401)
    stub_weapon(1401, :one_handed_spear)
    assert :ok = LkSpiralpierce.validate(caster, {:unit, 6_160}, 5, definition)

    stub(Combat, :resolve_combatant, fn 6_160 ->
      {:ok, CombatTestHelper.create_mob_combatant(unit_id: 6_160)}
    end)

    expect(Combat, :execute_skill_attack, fn ^caster, 6_160, opts ->
      assert opts[:base_damage] == 120
      assert opts[:skill_ratio] == 350
      assert opts[:ignore_defense] == true
      assert opts[:ignore_size] == true
      assert opts[:bonus_atk] == 7
      assert opts[:display_hit_count] == 5
      {:ok, %{hit?: false}}
    end)

    assert {:ok, ^caster} = LkSpiralpierce.cast(caster, {:unit, 6_160}, 5, definition)
  end

  @tag game_mode: :pre_renewal
  test "classic refuses swords before SP is consumed" do
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)
    stub_weapon(1101, :one_handed_sword)

    assert {:error, :wrong_weapon} =
             LkSpiralpierce.validate(caster(1101), {:unit, 6_160}, 1, definition)
  end

  @tag game_mode: :renewal
  test "Renewal admits a sword wielder" do
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)
    stub_weapon(1101, :one_handed_sword)
    assert :ok = LkSpiralpierce.validate(caster(1101), {:unit, 6_160}, 1, definition)
  end

  test "a level-seven mob row uses neutral ranged physical damage without weapon stats" do
    caster = mob([])
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)
    target_ref = {:player, 6_161}

    stub(Combat, :resolve_combatant, fn ^target_ref ->
      {:ok, CombatTestHelper.create_player_combatant(unit_id: 6_161)}
    end)

    expect(Combat, :execute_skill_attack, fn ^caster, ^target_ref, opts ->
      assert opts[:skill_id] == 397
      assert opts[:skill_level] == 5
      assert opts[:display_hit_count] == 5
      assert opts[:element] == :neutral
      assert opts[:ranged] == true
      assert opts[:skip_crit] == true
      refute Keyword.has_key?(opts, :weight_atk)
      refute Keyword.has_key?(opts, :base_damage)
      {:ok, %{hit?: false}}
    end)

    assert :ok =
             LkSpiralpierce.mob_cast(caster, {:unit, :player, 6_161}, 7, definition, %{level: 7})
  end

  test "a landed strike roots a normal mob for one second" do
    target = mob([])
    :ok = UnitRegistry.register_unit(:mob, target.instance_id, MobState, target, self())
    caster = caster(1401)
    stub_weapon(1401, :one_handed_spear)
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)

    stub(Combat, :resolve_combatant, fn 6_160 ->
      {:ok, CombatTestHelper.create_mob_combatant(unit_id: 6_160, class: :normal)}
    end)

    stub(Combat, :execute_skill_attack, fn _caster, 6_160, _opts -> {:ok, %{hit?: true}} end)

    :rand.seed(:exsss, {2, 3, 4})
    assert {:ok, ^caster} = LkSpiralpierce.cast(caster, {:unit, 6_160}, 5, definition)

    assert %{expires_at: expiry, started_at: start} =
             StatusStorage.get_status(:mob, 6_160, :sc_stop)

    assert expiry - start == 1_000
  end

  test "bosses and missed hits are never rooted" do
    caster = caster(1401)
    stub_weapon(1401, :one_handed_spear)
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)

    stub(Combat, :resolve_combatant, fn
      6_160 -> {:ok, CombatTestHelper.create_mob_combatant(unit_id: 6_160, class: :boss)}
      6_161 -> {:ok, CombatTestHelper.create_mob_combatant(unit_id: 6_161, class: :normal)}
    end)

    stub(Combat, :execute_skill_attack, fn _caster, target_id, _opts ->
      {:ok, %{hit?: target_id == 6_160}}
    end)

    reject(&StatusInterpreter.apply_status/4)
    assert {:ok, ^caster} = LkSpiralpierce.cast(caster, {:unit, 6_160}, 5, definition)
    assert {:ok, ^caster} = LkSpiralpierce.cast(caster, {:unit, 6_161}, 5, definition)
  end

  defp caster(nameid) do
    row = %InventoryItem{nameid: nameid, amount: 1, refine: 7, equip: 2, identify: 1}

    %PlayerState{
      character_id: 5_160,
      inventory: %{0 => row},
      stats: %Stats{
        equipment: %Equipment{right_hand: nameid},
        progression: %PlayerProgression{base_level: 99, job_id: 7}
      }
    }
  end

  defp mob(modes) do
    data = %MobDefinition{
      id: 1002,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 10,
      hp: 100,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      size: :medium,
      race: :brute,
      element: {:earth, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      modes: modes
    }

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 150, y: 150}
    }

    MobState.new(6_160, data, spawn, "prontera", 150, 150)
  end

  defp stub_weapon(id, subtype) do
    stub(ItemManagement, :get_item_by_id, fn ^id ->
      {:ok,
       %ItemDefinition{
         id: id,
         aegis_name: "test_weapon",
         name: "Test Weapon",
         type: :weapon,
         subtype: subtype,
         weight: 1_500
       }}
    end)
  end
end
