defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaMusicalstrikeTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Bard.BaMusicalstrike
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @caster_id 1_000
  @target_id 2_000
  @instrument_id 90_316
  @arrow_id 1_750
  @ammo_bit 0x008000

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()

    stub(ItemManagement, :get_item_by_id, fn @instrument_id ->
      {:ok,
       %ItemDefinition{
         id: @instrument_id,
         aegis_name: "task17_instrument",
         name: "Task 17 Instrument",
         type: :weapon,
         subtype: :musical,
         weapon_level: 1
       }}
    end)

    :ok
  end

  test "definition matches the pinned Musical Strike table" do
    assert {:ok, BaMusicalstrike} = Catalog.active_module_for(:ba_musicalstrike)
    assert {:ok, definition} = Catalog.by_id(316)

    assert definition.name == :ba_musicalstrike
    assert definition.display_name == "Musical Strike"
    assert definition.max_level == 5
    assert definition.target_type == :target_enemy
    assert definition.damage_type == :damage
    assert definition.damage_kind == :weapon
    assert definition.range == 9
    assert definition.require_weapon == [:musical]
    assert definition.requires_ammo
    assert definition.hit_count == 1
    assert definition.sp_cost == List.duplicate(12, 5)
    assert definition.cast_time == List.duplicate(500, 5)
    assert definition.fixed_cast_time == List.duplicate(0, 5)
    assert definition.after_cast_delay == List.duplicate(300, 5)
    assert definition.cooldown == List.duplicate(0, 5)
  end

  test "each level performs one aggregate ranged attack with two-hit presentation" do
    caster = %PlayerState{character_id: @caster_id}
    definition = BaMusicalstrike.definition()
    expected_ratios = [150, 190, 230, 270, 310]

    expect(Combat, :execute_skill_attack, 5, fn ^caster, 2_000, opts ->
      level = opts[:skill_level]
      assert opts[:skill_id] == 316
      assert opts[:skill_ratio] == Enum.at(expected_ratios, level - 1)
      assert opts[:hit_count] == 1
      assert opts[:display_hit_count] == 2
      assert opts[:ranged]
      assert opts[:skip_range]
      assert opts[:skip_crit]
      :ok
    end)

    for level <- 1..5 do
      assert {:ok, ^caster} =
               BaMusicalstrike.cast(caster, {:unit, @target_id}, level, definition)
    end
  end

  test "ordinary completion spends 12 SP and persists exactly one arrow after the attack succeeds" do
    caster = player_state()
    stub_target_at(18, 10)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:hit_count] == 1
      assert opts[:display_hit_count] == 2
      :ok
    end)

    before = System.monotonic_time(:millisecond)

    assert {:ok, updated} =
             Interpreter.complete_cast(caster, 316, 3, {:unit, @target_id})

    assert updated.stats.current_state.sp == 88
    assert updated.inventory[1].amount == 4
    assert [{_old, new_inventory, {:reduced, 1, 4}}] = updated.pending_inventory_persist
    assert new_inventory == updated.inventory
    assert updated.skill_cooldowns == %{}
    assert updated.act_delay_until >= before + 300
  end

  test "a failed aggregate attack spends no SP, arrow, delay, or cooldown" do
    caster = player_state()
    stub_target_at(18, 10)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
      {:error, :target_dead}
    end)

    assert {:error, :target_dead} =
             Interpreter.complete_cast(caster, 316, 3, {:unit, @target_id})

    assert_uncommitted(caster)
  end

  test "range, weapon, and ammo gates are atomic and never execute the attack" do
    reject(&Combat.execute_skill_attack/3)

    wrong_weapon = put_in(player_state().stats.equipment, %Equipment{})
    assert {:error, :wrong_weapon} = Interpreter.cast(wrong_weapon, 316, 3, {:unit, @target_id})
    assert_uncommitted(wrong_weapon)

    no_ammo = %{player_state() | inventory: %{}}
    stub_target_at(18, 10)
    assert {:error, :no_ammo} = Interpreter.cast(no_ammo, 316, 3, {:unit, @target_id})
    assert_uncommitted(no_ammo)

    out_of_range = player_state()
    stub_target_at(20, 10)
    assert {:error, :out_of_range} = Interpreter.cast(out_of_range, 316, 3, {:unit, @target_id})
    assert_uncommitted(out_of_range)
  end

  defp player_state do
    %PlayerState{
      character_id: @caster_id,
      x: 10,
      y: 10,
      map_name: "prontera",
      stats: %Stats{
        current_state: %{hp: 100, sp: 100},
        progression: %PlayerProgression{learned_skills: %{316 => 5}},
        equipment: %Equipment{right_hand: @instrument_id, ammo: @arrow_id}
      },
      inventory: %{
        1 => %InventoryItem{nameid: @arrow_id, amount: 5, equip: @ammo_bit}
      },
      zeny: 0
    }
  end

  defp target do
    %MobState{
      instance_id: @target_id,
      mob_id: 1_002,
      mob_data: nil,
      spawn_ref: nil,
      x: 18,
      y: 10,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }
  end

  defp stub_target_at(x, y) do
    mob = target()
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), mob, :mob} end)
    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {x, y, "prontera"}} end)
  end

  defp assert_uncommitted(state) do
    assert state.stats.current_state.sp == 100
    assert state.skill_cooldowns == %{}
    assert state.act_delay_until == 0
    assert state.pending_inventory_persist == []
  end
end
