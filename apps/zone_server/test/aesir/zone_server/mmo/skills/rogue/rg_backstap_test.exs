defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgBackstapTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgBackstap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  setup :verify_on_exit!

  setup do
    Mimic.copy(Cell)
    stub(Cell, :traversable?, fn "backstab", _x, _y -> true end)
    :ok
  end

  @caster_id 1_000
  @target_id 2_000
  @dagger_id 1_201
  @katar_id 1_250
  @bow_id 1_701
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
      map_name: "backstab",
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
      mob_data: Aesir.TestMob.definition(element: {:neutral, 1}, race: :formless, modes: []),
      spawn_ref: nil,
      map_name: "backstab",
      x: x,
      y: y,
      dir: dir,
      hp: 100,
      sp: 100,
      spawned_at: 0
    }
    |> Aesir.TestMob.publish(max_hp: 100, max_sp: 100)
  end

  test "ratio is 300 plus 40 per level and bows halve the part above the base 100" do
    assert RgBackstap.backstab_ratio(player(@katar_id, 10, 11), 1) == 340
    assert RgBackstap.backstab_ratio(player(@katar_id, 10, 11), 10) == 700
    assert RgBackstap.backstab_ratio(player(@dagger_id, 10, 11), 1) == 340
    assert RgBackstap.backstab_ratio(player(@bow_id, 10, 11), 1) == 220
    assert RgBackstap.backstab_ratio(player(@bow_id, 10, 11), 10) == 400
  end

  @tag game_mode: :renewal
  test "a rear attack rolls its hit and applies its stun chance on hit" do
    caster = player(@katar_id, 10, 11)
    attacker = %{caster | y: 9}
    target = mob(@target_id, 10, 10, 0)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    expect(Combat, :execute_skill_attack, fn ^attacker, @target_id, opts ->
      assert opts[:skill_id] == 212
      assert opts[:skill_level] == 3
      assert opts[:skill_ratio] == 420
      refute Keyword.has_key?(opts, :ignore_flee)
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

    assert {:ok, updated} = RgBackstap.cast(caster, {:unit, @target_id}, 3, definition())
    assert %ForcedMovement{x: 10, y: 9} = updated.pending_forced_movement
  end

  @tag game_mode: :pre_renewal
  test "a front attack is rejected before combat" do
    caster = player(@katar_id, 10, 9)
    target = mob(@target_id, 10, 10, 0)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    reject(&Combat.execute_skill_attack/3)
    reject(&StatusInterpreter.apply_status/4)

    assert {:failed, ^caster, :must_be_behind} =
             RgBackstap.cast(caster, {:unit, @target_id}, 1, definition())
  end

  @tag game_mode: :renewal
  test "mob casters slip by relocating themselves and attack from the slipped cell" do
    caster = mob(@caster_id, 10, 11, 0)
    attacker = %{caster | y: 9}
    target = mob(@target_id, 10, 10, 0)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)
    expect(Knockback, :relocate, fn :mob, @caster_id, 10, 9 -> {:ok, {10, 9}} end)

    expect(Combat, :execute_skill_attack, fn ^attacker, @target_id, opts ->
      assert opts[:skill_ratio] == 700
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

  @tag game_mode: :renewal
  test "a front attack is allowed and the caster slips behind the target" do
    caster = player(@katar_id, 10, 9)
    attacker = %{caster | y: 11}
    target = mob(@target_id, 10, 10, 0)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    expect(Combat, :execute_skill_attack, fn ^attacker, @target_id, opts ->
      assert opts[:skill_ratio] == 340
      assert opts[:hit_divisions] == 1
      {:ok, %{hit?: true, damage: 0, target_survives?: true}}
    end)

    stub(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stun, _opts -> :ok end)

    assert {:ok, updated} = RgBackstap.cast(caster, {:unit, @target_id}, 1, definition())
    assert %ForcedMovement{map_name: "backstab", x: 10, y: 11} = updated.pending_forced_movement
  end

  @tag game_mode: :renewal
  test "the caster slips behind the target before the attack, even one that misses" do
    caster = player(@katar_id, 10, 9)
    target = mob(@target_id, 10, 10, 0)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    stub(Combat, :execute_skill_attack, fn _caster, @target_id, _opts -> {:ok, %{hit?: false}} end)

    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, updated} = RgBackstap.cast(caster, {:unit, @target_id}, 1, definition())
    assert %ForcedMovement{map_name: "backstab", x: 10, y: 11} = updated.pending_forced_movement
  end

  @tag game_mode: :renewal
  test "the slip cell follows the 8-way direction from the caster to the target" do
    target = mob(@target_id, 10, 10, 0)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    stub(Combat, :execute_skill_attack, fn _caster, @target_id, _opts -> {:ok, %{hit?: false}} end)

    # {caster cell, slip cell}: an axis three times the other is straight.
    # Toward the east an exact 3:1 is straight horizontally; toward the west it
    # is straight only vertically. A caster on the target's cell steps east.
    for {{x, y}, slip} <- [
          {{10, 10}, {11, 10}},
          {{5, 9}, {11, 10}},
          {{7, 9}, {11, 10}},
          {{8, 9}, {11, 11}},
          {{13, 11}, {9, 9}},
          {{11, 13}, {10, 9}}
        ] do
      assert {:ok, updated} =
               RgBackstap.cast(player(@katar_id, x, y), {:unit, @target_id}, 1, definition())

      assert {updated.pending_forced_movement.x, updated.pending_forced_movement.y} == slip
    end
  end

  @tag game_mode: :renewal
  test "a wall on the straight line to the slip cell fails the skill" do
    caster = player(@katar_id, 7, 10)
    target = mob(@target_id, 10, 10, 0)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)
    stub(Cell, :traversable?, fn "backstab", x, y -> {x, y} != {8, 10} end)
    reject(&Combat.execute_skill_attack/3)

    assert {:failed, ^caster, :invalid_destination} =
             RgBackstap.cast(caster, {:unit, @target_id}, 1, definition())
  end

  @tag game_mode: :renewal
  test "a slip that cannot land fails the skill without attacking" do
    caster = player(@katar_id, 10, 9)
    target = mob(@target_id, 10, 10, 0)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)
    stub(Cell, :traversable?, fn "backstab", x, y -> {x, y} != {10, 11} end)
    reject(&Combat.execute_skill_attack/3)

    assert {:failed, ^caster, :invalid_destination} =
             RgBackstap.cast(caster, {:unit, @target_id}, 1, definition())
  end

  @tag game_mode: :renewal
  test "a dagger repeats the one calculated damage over two hits without touching the ratio" do
    caster = player(@dagger_id, 10, 11)
    attacker = %{caster | y: 9}
    target = mob(@target_id, 10, 10, 0)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    expect(Combat, :execute_skill_attack, fn ^attacker, @target_id, opts ->
      assert opts[:hit_divisions] == 2
      assert opts[:skill_ratio] == 340
      {:ok, %{hit?: false}}
    end)

    assert {:ok, _moved} = RgBackstap.cast(caster, {:unit, @target_id}, 1, definition())
  end

  @tag game_mode: :pre_renewal
  test "classic rear attack ignores flee and never stuns" do
    caster = player(@katar_id, 10, 11)
    target = mob(@target_id, 10, 10, 0)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)
    reject(&StatusInterpreter.apply_status/4)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == 420
      assert opts[:ignore_flee] == true
      assert opts[:hit_divisions] == 1
      {:ok, %{hit?: true, damage: 0, target_survives?: true}}
    end)

    assert {:ok, ^caster} = RgBackstap.cast(caster, {:unit, @target_id}, 3, definition())
  end

  @tag game_mode: :pre_renewal
  test "classic mob casters use the rear attack path without a stun" do
    caster = mob(@caster_id, 10, 11, 0)
    target = mob(@target_id, 10, 10, 0)
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)
    reject(&StatusInterpreter.apply_status/4)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == 700
      {:ok, %{hit?: true, damage: 0, target_survives?: true}}
    end)

    assert {:ok, ^caster} = RgBackstap.cast(caster, {:unit, @target_id}, 10, definition())
  end

  @tag game_mode: :renewal
  test "renewal carries the cooldown" do
    assert definition().sp_cost == List.duplicate(16, 10)
    assert definition().after_cast_delay == List.duplicate(500, 10)
    assert definition().cooldown == List.duplicate(500, 10)
  end

  @tag game_mode: :pre_renewal
  test "classic carries no cooldown" do
    assert definition().sp_cost == List.duplicate(16, 10)
    assert definition().after_cast_delay == List.duplicate(500, 10)
    assert definition().cooldown == []
  end
end
