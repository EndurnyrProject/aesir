defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsVenomknifeTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsVenomknife
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(SkillAttack)
    Catalog.reload()
    :ok
  end

  test "definition matches the Throw Venom Knife quest skill" do
    assert {:ok, AsVenomknife} = Catalog.active_module_for(:as_venomknife)
    assert {:ok, definition} = Catalog.by_id(1004)

    assert definition.name == :as_venomknife
    assert definition.display_name == "Throw Venom Knife"
    assert definition.max_level == 1
    assert definition.target_type == :target_enemy
    assert definition.damage_type == :damage
    assert definition.range == 9
    assert definition.sp_cost == [35]
    assert definition.requires_ammo
    assert definition.quest_skill
    assert definition.quest_owner_job == :assassin
  end

  test "validation requires the equipped Venom Knife item" do
    definition = AsVenomknife.definition()
    venom_knife = %InventoryItem{nameid: 1771, amount: 2, equip: 0x008000}
    arrow = %InventoryItem{nameid: 1750, amount: 2, equip: 0x008000}

    assert {:error, :no_ammo} =
             AsVenomknife.validate(%PlayerState{inventory: %{}}, {:unit, 2_000}, 1, definition)

    assert {:error, :wrong_ammo} =
             AsVenomknife.validate(
               %PlayerState{inventory: %{1 => arrow}},
               {:unit, 2_000},
               1,
               definition
             )

    assert :ok =
             AsVenomknife.validate(
               %PlayerState{inventory: %{1 => venom_knife}},
               {:unit, 2_000},
               1,
               definition
             )
  end

  test "a confirmed hit uses the forced neutral long no-card Auto Guard-exempt path and attempts Poison" do
    caster = %PlayerState{
      character_id: 1_000,
      inventory: %{1 => %InventoryItem{nameid: 1771, amount: 2, equip: 0x008000}}
    }

    expect(SkillAttack, :execute_forced_no_card_attack, fn ^caster, {:mob, 2_000}, opts ->
      assert opts == [
               skill_id: 1004,
               skill_level: 1,
               skill_ratio: 500,
               bonus_atk: 30,
               skip_crit: true,
               report_hit: true,
               skip_range: true
             ]

      {:ok, %{hit?: true, damage: 100, target_survives?: true}}
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, 2_000, :sc_poison, params ->
      assert params == [
               duration: 18_000,
               success_rate: 100,
               caster_id: 1_000,
               source_type: :player
             ]

      :ok
    end)

    assert {:ok, ^caster} =
             AsVenomknife.cast(caster, {:unit, {:mob, 2_000}}, 1, AsVenomknife.definition())
  end

  test "missing or wrong equipped ammo rejects the cast before any commitment" do
    reject(&SkillAttack.execute_forced_no_card_attack/3)
    wrong_ammo = player_state(1750)
    no_ammo = %{wrong_ammo | inventory: %{}}
    stub_target()

    assert {:error, :no_ammo} = Interpreter.cast(no_ammo, 1004, 1, {:unit, 2_000})
    assert_uncommitted(no_ammo)

    assert {:error, :wrong_ammo} = Interpreter.cast(wrong_ammo, 1004, 1, {:unit, 2_000})
    assert_uncommitted(wrong_ammo)
  end

  test "successful completion spends 35 SP and stages exactly one Venom Knife removal" do
    caster = player_state(1771)
    stub_target()

    expect(SkillAttack, :execute_forced_no_card_attack, fn ^caster, 2_000, _opts ->
      {:ok, %{hit?: true, damage: 100, target_survives?: true}}
    end)

    stub(UnitRegistry, :unit_exists?, fn :mob, 2_000 -> true end)
    expect(StatusInterpreter, :apply_status, fn :mob, 2_000, :sc_poison, _params -> :ok end)

    assert {:ok, updated} = Interpreter.complete_cast(caster, 1004, 1, {:unit, 2_000})
    assert updated.stats.current_state.sp == 65
    assert updated.inventory[1].amount == 1

    assert [{old_inventory, new_inventory, {:reduced, 1, 1}}] =
             updated.pending_inventory_persist

    assert old_inventory == caster.inventory
    assert new_inventory == updated.inventory
  end

  defp player_state(ammo_id) do
    %PlayerState{
      character_id: 1_000,
      x: 10,
      y: 10,
      map_name: "prontera",
      stats: %Stats{
        current_state: %{hp: 100, sp: 100},
        progression: %PlayerProgression{job_id: 12, learned_skills: %{1004 => 1}}
      },
      inventory: %{
        1 => %InventoryItem{nameid: ammo_id, amount: 2, equip: 0x008000}
      },
      zeny: 0
    }
    |> Aesir.ZoneServer.PlayerStateFixture.build()
  end

  defp stub_target do
    target = %MobState{
      instance_id: 2_000,
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

    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), target, :mob} end)
    stub(Combat, :resolve_target_position, fn 2_000 -> {:ok, :mob, {18, 10, "prontera"}} end)
  end

  defp assert_uncommitted(state) do
    assert state.stats.current_state.sp == 100
    assert state.skill_cooldowns == %{}
    assert state.act_delay_until == 0
    assert state.pending_inventory_persist == []

    if Map.has_key?(state.inventory, 1) do
      assert state.inventory[1].amount == 2
    end
  end
end
