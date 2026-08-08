defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgBackstapTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgBackstap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  setup :verify_on_exit!

  @caster_id 1_000
  @target_id 2_000
  @dagger_id 1_201
  @katar_id 1_250
  @right_hand 2

  defp definition do
    Catalog.reload()
    {:ok, definition} = Catalog.by_id(212)
    definition
  end

  defp player(weapon_id, x, y) do
    inventory = [%InventoryItem{nameid: weapon_id, amount: 1, equip: @right_hand, identify: 1}]

    %PlayerState{
      character_id: @caster_id,
      x: x,
      y: y,
      stats: %Stats{
        current_state: %CurrentState{hp: 100, sp: 100},
        derived_stats: %DerivedStats{max_hp: 100, max_sp: 100},
        progression: %PlayerProgression{learned_skills: %{}},
        equipment: Stats.equipment_from_inventory(inventory)
      }
    }
  end

  defp mob(id, x, y, dir) do
    %MobState{
      instance_id: id,
      mob_id: 1_002,
      mob_data: %{element: {:neutral, 1}, race: :formless, modes: []},
      spawn_ref: nil,
      map_name: "backstab",
      x: x,
      y: y,
      dir: dir,
      hp: 100,
      max_hp: 100,
      sp: 100,
      max_sp: 100,
      spawned_at: 0
    }
  end

  test "definition is discovered by the skill catalog" do
    skill = definition()

    assert skill.name == :rg_backstap
    assert skill.display_name == "Back Stab"
    assert skill.max_level == 10
    assert skill.target_type == :target_enemy
    assert skill.damage_type == :damage
    assert skill.range == 1
  end

  test "ratio is 200 plus 40 per level and daggers halve it" do
    assert RgBackstap.backstab_ratio(player(@katar_id, 10, 11), 1) == 240
    assert RgBackstap.backstab_ratio(player(@katar_id, 10, 11), 10) == 600
    assert RgBackstap.backstab_ratio(player(@dagger_id, 10, 11), 1) == 120
    assert RgBackstap.backstab_ratio(player(@dagger_id, 10, 11), 10) == 300
  end

  test "a rear attack ignores flee and applies its stun chance on hit" do
    caster = player(@katar_id, 10, 11)
    target = mob(@target_id, 10, 10, 0)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == 212
      assert opts[:skill_level] == 3
      assert opts[:skill_ratio] == 320
      assert opts[:ignore_flee] == true
      assert opts[:skip_range] == true
      assert opts[:report_hit] == true
      {:ok, %{hit?: true, damage: 0, target_survives?: true}}
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stun, opts ->
      assert opts[:success_rate] == 11
      assert opts[:caster_id] == @caster_id
      assert opts[:source_type] == :player
      :ok
    end)

    assert {:ok, ^caster} = RgBackstap.cast(caster, {:unit, @target_id}, 3, definition())
  end

  test "a front attack is rejected before combat" do
    caster = player(@katar_id, 10, 9)
    target = mob(@target_id, 10, 10, 0)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    reject(&Combat.execute_skill_attack/3)
    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :must_be_behind} =
             RgBackstap.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "mob casters use the same rear attack path" do
    caster = mob(@caster_id, 10, 11, 0)
    target = mob(@target_id, 10, 10, 0)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == 600
      {:ok, %{hit?: true, damage: 0, target_survives?: true}}
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stun, opts ->
      assert opts[:success_rate] == 25
      assert opts[:caster_id] == @caster_id
      assert opts[:source_type] == :mob
      :ok
    end)

    assert {:ok, ^caster} = RgBackstap.cast(caster, {:unit, @target_id}, 10, definition())
  end
end
