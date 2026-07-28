defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaPangvoiceTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Bard.BaPangvoice
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 1_000
  @target_id 2_000

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()
    :ok
  end

  test "definition matches the pinned Pang Voice table without a weapon requirement" do
    assert {:ok, BaPangvoice} = Catalog.active_module_for(:ba_pangvoice)
    assert {:ok, definition} = Catalog.by_id(1010)

    assert definition.name == :ba_pangvoice
    assert definition.display_name == "Pang Voice"
    assert definition.max_level == 1
    assert definition.target_type == :target_enemy
    assert definition.damage_type == :no_damage
    assert definition.range == 9
    assert definition.require_weapon == []
    assert definition.sp_cost == [40]
    assert definition.cast_time == [800]
    assert definition.fixed_cast_time == [200]
    assert definition.after_cast_delay == [2_000]
    assert definition.cooldown == [10_000]
    assert definition.quest_skill
  end

  test "boss validation is atomic before either status application" do
    boss = register_mob([:boss], 18, 10)
    caster = player_state()

    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :boss_immune} =
             Interpreter.cast(caster, 1010, 1, {:unit, boss.instance_id})

    assert caster.stats.current_state.sp == 100
    assert caster.skill_cooldowns == %{}
    assert caster.act_delay_until == 0
  end

  test "range validation rejects a target ten cells away before either status application" do
    target = register_mob([], 20, 10)
    caster = player_state()

    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :out_of_range} =
             Interpreter.cast(caster, 1010, 1, {:unit, target.instance_id})
  end

  test "confusion resistance does not prevent bleeding and the validated cast succeeds" do
    target = register_mob([], 18, 10)
    caster = %PlayerState{character_id: @caster_id}

    expect(StatusInterpreter, :apply_status, 2, fn :mob, @target_id, status, opts ->
      assert opts == [
               duration: 10_000,
               success_rate: 100,
               caster_id: @caster_id,
               source_type: :player
             ]

      send(self(), {:status_attempted, status})

      case status do
        :sc_confusion -> {:error, :resisted}
        :sc_bleeding -> :ok
      end
    end)

    assert :ok = BaPangvoice.validate(caster, {:unit, target.instance_id}, 1, nil)
    assert {:ok, ^caster} = BaPangvoice.cast(caster, {:unit, target.instance_id}, 1, nil)
    assert_received {:status_attempted, :sc_confusion}
    assert_received {:status_attempted, :sc_bleeding}
  end

  test "mob casters identify themselves and apply both statuses to a player target" do
    caster = mob_state(@caster_id, [], 10, 10)
    target = %PlayerState{character_id: @target_id, x: 11, y: 10, map_name: "prontera"}
    UnitRegistry.register_unit(:player, @target_id, PlayerState, target, self())

    expect(StatusInterpreter, :apply_status, 2, fn :player, @target_id, status, opts ->
      assert status in [:sc_confusion, :sc_bleeding]
      assert opts[:caster_id] == @caster_id
      assert opts[:source_type] == :mob
      {:error, :resisted}
    end)

    assert :ok = BaPangvoice.validate(caster, {:unit, @target_id}, 1, nil)
    assert {:ok, ^caster} = BaPangvoice.cast(caster, {:unit, @target_id}, 1, nil)
  end

  defp player_state do
    %PlayerState{
      character_id: @caster_id,
      x: 10,
      y: 10,
      map_name: "prontera",
      stats: %Stats{
        current_state: %{hp: 100, sp: 100},
        progression: %PlayerProgression{job_id: 19, learned_skills: %{1010 => 1}}
      }
    }
  end

  defp register_mob(modes, x, y) do
    state = mob_state(@target_id, modes, x, y)
    UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())
    :ok = SpatialIndex.update_unit_position(:mob, state.instance_id, x, y, "prontera")
    state
  end

  defp mob_state(instance_id, modes, x, y) do
    mob_data = %MobDefinition{
      id: 1_002,
      aegis_name: "TEST_MOB",
      name: "Test Mob",
      level: 25,
      hp: 1_000,
      sp: 100,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      skill_range: 9,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1_200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      modes: modes
    }

    spawn_ref = %MobSpawn{
      mob: 1_002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: x, y: y}
    }

    MobState.new(instance_id, mob_data, spawn_ref, "prontera", x, y)
  end
end
