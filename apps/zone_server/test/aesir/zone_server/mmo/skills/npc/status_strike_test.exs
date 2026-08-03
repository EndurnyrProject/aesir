defmodule Aesir.ZoneServer.Mmo.Skills.Npc.StatusStrikeTest do
  @moduledoc """
  Coverage for the shared `cast/5` body behind every NPC status-attack skill
  module (`NPC_STUNATTACK`, `NPC_POISON`, ...): the attack, the status rider
  gated on a connecting hit, and the mob-caster range widening to
  `max(attack_range, skill_range)`.
  """

  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skills.Npc.StatusStrike
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 5001
  @target_id 2000
  @map "prontera"

  defp definition(element \\ :poison) do
    %{id: 176, element: element}
  end

  defp mob_caster(attack_range \\ 1, skill_range \\ 9) do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "TEST_CASTER",
      name: "Test Caster",
      level: 25,
      hp: 1000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: attack_range,
      skill_range: skill_range,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(@caster_id, mob_data, spawn_ref, @map, 100, 100)
  end

  test "hits with 100% weapon ratio in the skill's element and applies the status" do
    caster = mob_caster()

    expect(Combat, :execute_skill_attack, fn passed_caster, @target_id, opts ->
      assert passed_caster.mob_data.attack_range == 9
      assert opts[:skill_id] == 176
      assert opts[:skill_level] == 4
      assert opts[:skill_ratio] == 100
      assert opts[:element] == :poison
      assert opts[:skip_crit] == true
      assert opts[:report_hit] == true
      {:ok, %{hit?: true}}
    end)

    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_poison, opts ->
      assert opts[:val1] == 4
      assert opts[:caster_id] == @caster_id
      assert opts[:source_id] == @caster_id
      assert opts[:source_type] == :mob
      :ok
    end)

    assert {:ok, ^caster} =
             StatusStrike.cast(caster, @target_id, 4, definition(), :sc_poison)
  end

  test "preserves a typed Homunculus target for damage and status delivery" do
    caster = mob_caster()
    target_ref = {:homunculus, 1_500_001}

    expect(Combat, :execute_skill_attack, fn _caster, ^target_ref, _opts ->
      {:ok, %{hit?: true}}
    end)

    reject(&UnitRegistry.unit_exists?/2)

    expect(StatusInterpreter, :apply_status, fn :homunculus, 1_500_001, :sc_poison, opts ->
      assert opts[:source_type] == :mob
      :ok
    end)

    assert {:ok, ^caster} =
             StatusStrike.cast(caster, target_ref, 1, definition(), :sc_poison)
  end

  test "widens a mob caster's attack range only up to its skill range" do
    caster = mob_caster(12, 9)

    expect(Combat, :execute_skill_attack, fn passed_caster, @target_id, _opts ->
      assert passed_caster.mob_data.attack_range == 12
      {:ok, %{hit?: false}}
    end)

    assert {:ok, ^caster} = StatusStrike.cast(caster, @target_id, 1, definition(), :sc_poison)
  end

  test "does not apply the status on a miss, but still returns {:ok, caster}" do
    caster = mob_caster()

    stub(Combat, :execute_skill_attack, fn _caster, @target_id, _opts -> {:ok, %{hit?: false}} end)

    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} = StatusStrike.cast(caster, @target_id, 5, definition(), :sc_stun)
  end

  test "propagates a Combat error without applying the status" do
    caster = mob_caster()

    stub(Combat, :execute_skill_attack, fn _caster, @target_id, _opts ->
      {:error, :target_out_of_range}
    end)

    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :target_out_of_range} =
             StatusStrike.cast(caster, @target_id, 5, definition(), :sc_stun)
  end

  test "applies the status to a player target when the mob lookup misses" do
    caster = mob_caster()

    stub(Combat, :execute_skill_attack, fn _caster, @target_id, _opts -> {:ok, %{hit?: true}} end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> false end)

    expect(StatusInterpreter, :apply_status, fn :player, @target_id, :sc_curse, opts ->
      assert opts[:source_type] == :mob
      :ok
    end)

    assert {:ok, ^caster} =
             StatusStrike.cast(caster, @target_id, 2, definition(:shadow), :sc_curse)
  end

  test "derives caster_id and source_type from a player caster" do
    caster = %PlayerState{character_id: 777}

    stub(Combat, :execute_skill_attack, fn _caster, @target_id, _opts -> {:ok, %{hit?: true}} end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_poison, opts ->
      assert opts[:caster_id] == 777
      assert opts[:source_id] == 777
      assert opts[:source_type] == :player
      :ok
    end)

    assert {:ok, ^caster} = StatusStrike.cast(caster, @target_id, 3, definition(), :sc_poison)
  end
end
