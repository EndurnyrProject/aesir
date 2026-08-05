defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsSonicblowTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsSonicblow
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 1000
  @target_id 2000
  @katar_id 1250
  @dagger_id 1201
  @both_hands 34
  @right_hand 2

  defp definition do
    Catalog.reload()
    {:ok, definition} = Catalog.by_id(136)
    definition
  end

  defp player(learned_skills \\ %{}, weapon_id \\ @katar_id, equip \\ @both_hands) do
    inventory = [%InventoryItem{nameid: weapon_id, amount: 1, equip: equip, identify: 1}]

    %PlayerState{
      character_id: @caster_id,
      stats: %Stats{
        combat_stats: %CombatStats{hit: 101},
        current_state: %CurrentState{hp: 100, sp: 100},
        derived_stats: %DerivedStats{max_hp: 100, max_sp: 100},
        progression: %PlayerProgression{learned_skills: learned_skills},
        equipment: Stats.equipment_from_inventory(inventory)
      }
    }
  end

  defp mob(id, hp, max_hp) do
    %MobState{
      instance_id: id,
      mob_id: 1002,
      mob_data: %{element: {:neutral, 1}, race: :formless, modes: []},
      spawn_ref: nil,
      map_name: "sonic",
      x: 10,
      y: 10,
      hp: hp,
      max_hp: max_hp,
      sp: 100,
      max_sp: 100,
      spawned_at: 0
    }
  end

  test "definition publishes one eight-display-hit Katar attack" do
    skill = definition()

    assert skill.name == :as_sonicblow
    assert skill.max_level == 10
    assert skill.target_type == :target_enemy
    assert skill.range == 1
    assert skill.sp_cost == Enum.to_list(16..34//2)
    assert skill.cooldown == List.duplicate(1_000, 10)
    assert skill.hit_count == 1
    assert skill.require_weapon == [:katar]
    assert skill.requires == []
    assert AsSonicblow.__requires_declared__()
  end

  test "player validation requires a Katar while mobs bypass equipment" do
    assert :ok = AsSonicblow.validate(player(), {:unit, @target_id}, 1, definition())

    dagger = player(%{}, @dagger_id, @right_hand)

    assert {:error, :wrong_weapon} =
             AsSonicblow.validate(dagger, {:unit, @target_id}, 1, definition())

    assert :ok =
             AsSonicblow.validate(mob(@caster_id, 100, 100), {:unit, @target_id}, 1, definition())
  end

  test "minimum level uses the strict below-half ratio and one mechanical hit" do
    caster = player()
    target = mob(@target_id, 49, 100)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    expect(Combat, :execute_sonic_blow_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == 450
      assert opts[:accelerated] == false
      assert opts[:display_hit_count] == 8
      assert opts[:hit_count] == 1
      assert opts[:skip_crit] == true
      assert opts[:report_hit] == true
      {:ok, %{hit?: true, damage: 0, target_survives?: true}}
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stun, opts ->
      assert opts[:duration] == 4_500
      assert opts[:success_rate] == 12
      assert opts[:caster_id] == @caster_id
      assert opts[:source_type] == :player
      refute Keyword.has_key?(opts, :bypass_resistance)
      :ok
    end)

    assert {:ok, ^caster} = AsSonicblow.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "exactly half HP does not receive the low-HP multiplier" do
    caster = player()
    target = mob(@target_id, 50, 100)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    expect(Combat, :execute_sonic_blow_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == 300
      {:ok, %{hit?: false, damage: 0, target_survives?: true}}
    end)

    reject(&StatusInterpreter.apply_status/4)
    assert {:ok, ^caster} = AsSonicblow.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "maximum level marks a granted player for exact final acceleration" do
    accel_id = 1003
    caster = player(%{accel_id => 1})
    target = mob(@target_id, 100, 100)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    expect(Combat, :execute_sonic_blow_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == 1_200
      assert opts[:accelerated] == true
      {:ok, %{hit?: true, damage: 2_280, target_survives?: false}}
    end)

    stub(StatusInterpreter, :apply_status, fn _, _, _, _ -> :ok end)
    assert {:ok, ^caster} = AsSonicblow.cast(caster, {:unit, @target_id}, 10, definition())
  end

  test "mob Sonic Blow gets low-HP damage and Stun but never acceleration" do
    caster = mob(@caster_id, 100, 100)

    target = %PlayerState{
      character_id: @target_id,
      stats: %Stats{
        current_state: %CurrentState{hp: 49},
        derived_stats: %DerivedStats{max_hp: 100}
      }
    }

    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :player} end)

    expect(Combat, :execute_sonic_blow_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == 1_800
      assert opts[:accelerated] == false
      {:ok, %{hit?: true, damage: 10, target_survives?: true}}
    end)

    expect(StatusInterpreter, :apply_status, fn :player, @target_id, :sc_stun, opts ->
      assert opts[:success_rate] == 30
      assert opts[:source_type] == :mob
      :ok
    end)

    assert {:ok, ^caster} = AsSonicblow.cast(caster, {:unit, @target_id}, 10, definition())
  end

  test "real combat boundary accelerates HIT and final damage once while displaying eight" do
    Mimic.copy(DamageCalculator)
    Mimic.copy(HitCalculations)
    Mimic.copy(MobState)
    caster = player(%{1003 => 1})
    attacker = combatant(@caster_id, :player, 101)
    target = combatant(@target_id, :mob, 0)
    target_state = mob(@target_id, 100, 100)
    test_pid = self()

    stub(PlayerState, :to_combatant, fn accelerated ->
      send(test_pid, {:accelerated_hit, accelerated.stats.combat_stats.hit})

      %{
        attacker
        | combat_stats: %{attacker.combat_stats | hit: accelerated.stats.combat_stats.hit}
      }
    end)

    stub(MobState, :to_combatant, fn ^target_state -> target end)

    stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
      {:ok, {MobState, target_state, self()}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id -> {:ok, {10, 10, "sonic"}} end)
    stub(StatusInterpreter, :before_weapon_hit, fn :mob, @target_id, _info -> :continue end)

    expect(HitCalculations, :calculate_hit_result, fn attacker_stats, _target_stats ->
      assert attacker_stats.hit == 191
      :hit
    end)

    expect(DamageCalculator, :calculate_damage, fn passed_attacker, ^target, opts ->
      assert passed_attacker.combat_stats.hit == 191
      assert opts[:skill_ratio] == 300
      {:ok, %{damage: 101, is_critical: false}}
    end)

    reject(&DamageCalculator.calculate_secondary_hand_damage/3)
    stub(StatusInterpreter, :absorb_damage, fn :mob, @target_id, damage, _info -> damage end)

    expect(Broadcast, :to_in_range, fn _, _, _, _, %SkillDamage{} = packet ->
      send(test_pid, {:packet, packet})
      :ok
    end)

    expect(MobSession, :apply_damage, fn _, 191, @caster_id -> :ok end)

    assert {:ok, %{hit?: true, damage: 191}} =
             Combat.execute_sonic_blow_attack(caster, @target_id,
               skill_id: 136,
               skill_level: 1,
               skill_ratio: 300,
               accelerated: true,
               display_hit_count: 8,
               hit_count: 1,
               skip_crit: true,
               report_hit: true,
               skip_range: true
             )

    assert_received {:accelerated_hit, 191}
    assert_received {:packet, %SkillDamage{damage: 191, div: 8}}
  end

  test "a miss skips Stun while a fully absorbed connected hit still attempts it" do
    caster = player()
    target = mob(@target_id, 100, 100)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    expect(Combat, :execute_sonic_blow_attack, 2, fn ^caster, @target_id, _opts ->
      case Process.get(:sonic_cast, :miss) do
        :miss ->
          Process.put(:sonic_cast, :absorbed)
          {:ok, %{hit?: false, damage: 0, target_survives?: true}}

        :absorbed ->
          {:ok, %{hit?: true, damage: 0, target_survives?: true}}
      end
    end)

    expect(StatusInterpreter, :apply_status, 1, fn :mob, @target_id, :sc_stun, _opts -> :ok end)

    assert {:ok, ^caster} = AsSonicblow.cast(caster, {:unit, @target_id}, 1, definition())
    assert {:ok, ^caster} = AsSonicblow.cast(caster, {:unit, @target_id}, 1, definition())
  end

  defp combatant(unit_id, unit_type, hit) do
    Combatant.new!(%{
      unit_id: unit_id,
      unit_type: unit_type,
      base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{
        atk: 100,
        def: 0,
        hit: hit,
        flee: 0,
        perfect_dodge: 0,
        critical: 0,
        max_weapon_damage: true
      },
      progression: %{base_level: 1, job_level: 1},
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      weapon: %{type: :katar, element: :neutral, size: :medium},
      attack_range: 1,
      attack_delay_ms: 500,
      position: {10, 10},
      map_name: "sonic"
    })
  end
end
