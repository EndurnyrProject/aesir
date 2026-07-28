defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaDissonanceTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Bard.BaDissonance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule UnitStub do
    def get_entity_info(_state), do: %{stats: %{}}
  end

  @caster_id 1_000
  @instrument_id 90_317

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()

    stub(ItemManagement, :get_item_by_id, fn @instrument_id ->
      {:ok,
       %ItemDefinition{
         id: @instrument_id,
         aegis_name: "task19_instrument",
         name: "Task 19 Instrument",
         type: :weapon,
         subtype: :musical,
         weapon_level: 1
       }}
    end)

    :ok
  end

  test "definition matches the pinned Dissonance table" do
    assert {:ok, BaDissonance} = Catalog.active_module_for(:ba_dissonance)
    assert {:ok, definition} = Catalog.by_id(317)

    assert definition.name == :ba_dissonance
    assert definition.display_name == "Dissonance"
    assert definition.max_level == 5
    assert definition.target_type == :self
    assert definition.damage_type == :damage
    assert definition.damage_kind == :magic
    assert definition.element == :neutral
    assert definition.range == 0
    assert definition.splash_radius == 4
    assert definition.hit_count == 1
    assert definition.require_weapon == [:musical]
    assert definition.sp_cost == [35, 38, 41, 44, 47]
    assert definition.cast_time == List.duplicate(1_000, 5)
    assert definition.fixed_cast_time == List.duplicate(300, 5)
    assert definition.after_cast_delay == List.duplicate(300, 5)
    assert definition.cooldown == List.duplicate(5_000, 5)
  end

  test "each level executes one enemy neutral magic radius-four splash with exact job scaling" do
    for {level, job_level} <- [{1, 1}, {2, 7}, {3, 23}, {4, 49}, {5, 50}] do
      caster = player_state(job_level)

      expect(Combat, :execute_magic_splash, fn ^caster, {10, 20}, 4, opts ->
        assert opts[:skill_id] == 317
        assert opts[:skill_level] == level
        assert opts[:skill_ratio] == div((110 + 50 * level) * job_level, 10)
        assert opts[:element] == :neutral
        assert opts[:split] == false
        []
      end)

      assert {:ok, result} = BaDissonance.cast(caster, :self, level, BaDissonance.definition())
      assert result.last_song == %{skill_id: 317, level: level}
      refute_receive {:skill, _}
    end
  end

  test "mob casting accepts only its executor-shaped self target without player song memory" do
    caster = mob_state()

    expect(Combat, :execute_magic_splash, fn ^caster, {10, 20}, 4, opts ->
      assert opts[:skill_ratio] == 360
      assert opts[:element] == :neutral
      []
    end)

    assert {:ok, ^caster} =
             BaDissonance.cast(
               caster,
               {:unit, caster.instance_id},
               5,
               BaDissonance.definition()
             )
  end

  test "dynamic cost uses Bard ordering and applies Adaptation last" do
    caster = player_state(50)
    :ok = UnitRegistry.register_unit(:player, @caster_id, UnitStub, %{}, self())
    :ok = StatusStorage.apply_status(:player, @caster_id, :sc_adaptation, duration: 10_000)

    assert %Cost{sp: 28, sp_requirement: 28} =
             BaDissonance.dynamic_cost(caster, :self, 1, BaDissonance.definition())
  end

  test "weapon validation failure preserves memory and ordinary commitment" do
    caster = player_state(50)

    caster = %{
      caster
      | last_song: %{skill_id: 319, level: 3},
        stats: %{caster.stats | equipment: %Equipment{}}
    }

    reject(&Combat.execute_magic_splash/4)

    assert {:error, :wrong_weapon} = Interpreter.cast(caster, 317, 5, :self)
    assert caster.last_song == %{skill_id: 319, level: 3}
    assert caster.stats.current_state.sp == 100
    assert caster.skill_cooldowns == %{}
    assert caster.act_delay_until == 0
  end

  defp player_state(job_level) do
    %PlayerState{
      character_id: @caster_id,
      x: 10,
      y: 20,
      map_name: "prontera",
      stats: %Stats{
        base_stats: %{dex: 1, int: 1},
        current_state: %{hp: 100, sp: 100},
        derived_stats: %{max_hp: 100, max_sp: 100},
        progression: %PlayerProgression{
          job_level: job_level,
          learned_skills: %{317 => 5}
        },
        equipment: %Equipment{right_hand: @instrument_id}
      }
    }
  end

  defp mob_state do
    %MobState{
      instance_id: @caster_id,
      mob_id: 2_226,
      mob_data: nil,
      spawn_ref: nil,
      x: 10,
      y: 20,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 100,
      max_sp: 100,
      spawned_at: 0
    }
  end
end
