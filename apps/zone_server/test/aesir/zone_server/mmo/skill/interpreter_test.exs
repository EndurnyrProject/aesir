defmodule Aesir.ZoneServer.Mmo.Skill.InterpreterTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Id, as: SkillUnitId
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmProvoke
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Suffragium
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.TestSupport.EnsembleSkill
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  defmodule OriginAwareSkill do
    @behaviour Aesir.ZoneServer.Mmo.Skill.Active

    @impl true
    def cast(game_state, _target, _level, _definition) do
      send(self(), {:cast_origin, :fallback})
      {:ok, game_state}
    end

    @impl true
    def cast_with_origin(game_state, _target, _level, _definition, origin) do
      send(self(), {:cast_origin, origin})
      {:ok, game_state}
    end

    @impl true
    def validate(_game_state, _target, _level, _definition), do: :ok
  end

  defmodule InputAwareSkill do
    @behaviour Aesir.ZoneServer.Mmo.Skill.Active

    @impl true
    def cast(game_state, _target, _level, _definition) do
      send(self(), :ordinary_input_fallback)
      {:ok, game_state}
    end

    @impl true
    def cast_with_input(game_state, _target, _level, _definition, input) do
      send(self(), {:input_cast, input})
      {:ok, game_state}
    end

    @impl true
    def validate(_game_state, _target, _level, _definition), do: :ok
  end

  defmodule StaticCostSkill do
    @behaviour Aesir.ZoneServer.Mmo.Skill.Active

    @impl true
    def cast(game_state, _target, _level, _definition) do
      send(self(), {:cost_skill_sp, game_state.stats.current_state.sp})
      {:ok, game_state}
    end

    @impl true
    def validate(_game_state, _target, _level, _definition), do: :ok
  end

  defmodule DynamicCostSkill do
    @behaviour Aesir.ZoneServer.Mmo.Skill.Active

    alias Aesir.ZoneServer.Mmo.Skill.Cost

    @impl true
    def cast(game_state, _target, _level, _definition) do
      send(self(), {:cost_skill_sp, game_state.stats.current_state.sp})
      {:ok, game_state}
    end

    @impl true
    def validate(_game_state, _target, _level, _definition), do: :ok

    @impl true
    def dynamic_cost(_game_state, _target, _level, _definition) do
      sp = Process.get(:interpreter_test_dynamic_sp)
      send(self(), {:dynamic_cost_prepared, sp})
      %Cost{sp: sp}
    end
  end

  defmodule DeferredCostSkill do
    @behaviour Aesir.ZoneServer.Mmo.Skill.Active

    @impl true
    def cast(game_state, _target, _level, _definition),
      do: {:deferred, game_state, :spirit_action}

    @impl true
    def validate(_game_state, _target, _level, _definition), do: :ok
  end

  defmodule MalformedCostSkill do
    @behaviour Aesir.ZoneServer.Mmo.Skill.Active

    @impl true
    def cast(game_state, _target, _level, _definition) do
      send(self(), :malformed_cost_effect)
      {:ok, game_state}
    end

    @impl true
    def validate(_game_state, _target, _level, _definition), do: :ok

    @impl true
    def dynamic_cost(_game_state, _target, _level, _definition),
      do: Process.get(:interpreter_test_dynamic_cost)
  end

  defmodule ResourceChangingCostSkill do
    @behaviour Aesir.ZoneServer.Mmo.Skill.Active

    alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

    @impl true
    def cast(game_state, _target, _level, _definition) do
      send(self(), :resource_changing_effect)
      {:ok, Map.put(game_state, :spirit_spheres, SpiritSpheres.new())}
    end

    @impl true
    def validate(_game_state, _target, _level, _definition), do: :ok
  end

  defmodule CompletionValidationSkill do
    @behaviour Aesir.ZoneServer.Mmo.Skill.Active

    @impl true
    def cast(game_state, _target, _level, _definition) do
      send(self(), :completion_validation_effect)
      {:ok, game_state}
    end

    @impl true
    def validate(_game_state, _target, _level, _definition) do
      if Process.get(:interpreter_test_allow_cast?, false),
        do: :ok,
        else: {:error, :requirements_changed}
    end
  end

  defmodule DynamicCastTimeSkill do
    @behaviour Aesir.ZoneServer.Mmo.Skill.Active

    @impl true
    def cast(game_state, _target, _level, _definition), do: {:ok, game_state}

    @impl true
    def validate(_game_state, _target, _level, _definition), do: :ok

    @impl true
    def dynamic_cast_time(_game_state, _target, _level, definition) do
      if Process.get(:interpreter_test_instant_cast?, false) do
        %{cast_time: 0, fixed_cast_time: 0}
      else
        %{
          cast_time: Enum.at(definition.cast_time, 0),
          fixed_cast_time: Enum.at(definition.fixed_cast_time, 0)
        }
      end
    end
  end

  defp game_state(sp, learned) do
    %PlayerState{
      character_id: 1000,
      x: 10,
      y: 10,
      map_name: "prontera",
      action_state: :idle,
      movement_state: :standing,
      skill_cooldowns: %{},
      act_delay_until: 0,
      stats: %PlayerStats{
        base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
        current_state: %CurrentState{sp: sp, hp: 100},
        derived_stats: %DerivedStats{max_sp: 200, max_hp: 100},
        progression: %PlayerProgression{learned_skills: learned},
        equipment: %Equipment{}
      }
    }
  end

  defp game_state(sp, learned, equipment) do
    gs = game_state(sp, learned)
    %{gs | stats: %{gs.stats | modifiers: %Modifiers{equipment: equipment}}}
  end

  defp stub_provoke_target(target_id) do
    stub(TargetResolver, :resolve, fn ^target_id ->
      {:ok, self(), struct(MobState, instance_id: target_id, hp: 1, max_hp: 1), :mob}
    end)
  end

  defp resurrection_game_state do
    %{
      game_state(100, %{54 => 1})
      | inventory: %{0 => %InventoryItem{nameid: 717, amount: 1, equip: 0}},
        pending_inventory_persist: []
    }
  end

  defp resurrection_mob do
    %MobState{
      instance_id: 2_000,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      x: 14,
      y: 10,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }
  end

  defp enemy_definition(range) do
    %Definition{
      id: 6,
      name: :sm_provoke,
      display_name: "Provoke",
      max_level: 10,
      target_type: :target_enemy,
      damage_type: :no_damage,
      range: range,
      sp_cost: List.duplicate(9, 10)
    }
  end

  describe "cast origins" do
    setup do
      definition = %Definition{
        id: 29,
        name: :origin_aware,
        display_name: "Origin Aware",
        max_level: 1,
        target_type: :self,
        sp_cost: [0]
      }

      homunculus_definition = %{definition | id: 8_001, cast_time: [100]}

      stub(Catalog, :by_id, fn
        29 -> {:ok, definition}
        8_001 -> {:ok, homunculus_definition}
      end)

      stub(Catalog, :active_module_for, fn :origin_aware -> {:ok, OriginAwareSkill} end)
      :ok
    end

    test "normal casts dispatch normal origin" do
      assert {:ok, _} = Interpreter.cast(game_state(100, %{29 => 1}), 29, 1, :self)
      assert_received {:cast_origin, :normal}
    end

    test "timed Homunculus casts keep the shared begin shape and dispatch their origin" do
      caster = %HomunculusState{
        id: 1,
        owner_character_id: 100,
        owner_session_pid: self(),
        class_id: 6_001,
        name: "Lif",
        lifecycle: :active,
        hp: 100,
        sp: 100,
        learned_skills: %{8_001 => 1},
        world_gid: 1_500_001,
        map_name: "prontera",
        x: 10,
        y: 10
      }

      assert {:casting, ^caster, %{skill_id: 8_001}} =
               Interpreter.begin_cast(caster, 8_001, 1, :self)

      assert {:ok, _updated} =
               Interpreter.complete_cast(%{caster | action_state: :casting}, 8_001, 1, :self)

      assert_received {:cast_origin, :homunculus}
    end

    test "item casts dispatch item origin" do
      assert {:ok, _} = Interpreter.item_cast(game_state(100, %{}), 29, 1, :self)
      assert_received {:cast_origin, :item}
    end

    test "auto casts dispatch auto origin" do
      assert {:ok, _} = Interpreter.auto_cast(game_state(100, %{}), 29, 1, :self)
      assert_received {:cast_origin, :auto}
    end
  end

  test "unknown skill returns :unknown_skill" do
    assert {:error, :unknown_skill} =
             Interpreter.cast(game_state(100, %{29 => 1}), 999_999, 1, :self)
  end

  test "skill not learned returns :skill_not_learned" do
    assert {:error, :skill_not_learned} =
             Interpreter.cast(game_state(100, %{}), 29, 1, :self)
  end

  test "a copied skill casts at its recorded level" do
    definition = %Definition{
      id: 6,
      name: :sm_provoke,
      display_name: "Copied Skill",
      max_level: 2,
      target_type: :self,
      sp_cost: [0, 0],
      cast_time: [0, 0]
    }

    stub(Catalog, :by_id, fn 6 -> {:ok, definition} end)

    stub(SmProvoke, :cast, fn caster, :self, level, _definition ->
      send(self(), {:copied_skill_cast, level})
      {:ok, caster}
    end)

    state = %{game_state(100, %{}) | plagiarized: %{skill_id: 6, level: 2}}

    assert {:ok, _updated} = Interpreter.cast(state, 6, 2, :self)
    assert_received {:copied_skill_cast, 2}
  end

  test "casting above learned level returns :skill_not_learned" do
    assert {:error, :skill_not_learned} =
             Interpreter.cast(game_state(100, %{29 => 1}), 29, 5, :self)
  end

  test "a retained quest skill casts only on its owner lineage" do
    definition =
      Definition.build!(
        [
          id: 29,
          name: :origin_aware,
          display_name: "Fixture Archer Quest",
          max_level: 1,
          target_type: :self,
          sp_cost: [0],
          quest_skill: true,
          quest_owner_job: :archer
        ],
        __MODULE__
      )

    stub(Catalog, :by_id, fn 29 -> {:ok, definition} end)
    stub(Catalog, :active_module_for, fn :origin_aware -> {:ok, OriginAwareSkill} end)

    off_lineage =
      put_in(
        game_state(100, %{29 => 1}),
        [Access.key!(:stats), Access.key!(:progression), Access.key!(:job_id)],
        1
      )

    eligible =
      put_in(
        game_state(100, %{29 => 1}),
        [Access.key!(:stats), Access.key!(:progression), Access.key!(:job_id)],
        11
      )

    assert {:error, :skill_not_learned} = Interpreter.cast(off_lineage, 29, 1, :self)
    assert {:ok, _updated} = Interpreter.cast(eligible, 29, 1, :self)
  end

  test "insufficient SP returns :insufficient_sp and does not apply the effect" do
    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :insufficient_sp} =
             Interpreter.cast(game_state(1, %{29 => 1}), 29, 1, :self)
  end

  describe "input-aware casts" do
    setup do
      definition = %Definition{
        id: 29,
        name: :input_aware,
        display_name: "Input Aware",
        max_level: 1,
        target_type: :self,
        sp_cost: [10],
        cooldown: [10_000]
      }

      stub(Catalog, :by_id, fn 29 -> {:ok, definition} end)
      stub(Catalog, :active_module_for, fn :input_aware -> {:ok, InputAwareSkill} end)
      :ok
    end

    test "preflight validates without mutating resources or running the callback" do
      initial = game_state(50, %{29 => 1})

      assert :ok = Interpreter.preflight_cast(initial, 29, 1, :self)
      assert initial.stats.current_state.sp == 50
      assert initial.skill_cooldowns == %{}
      refute_received {:input_cast, _input}
      refute_received :ordinary_input_fallback
    end

    test "completion invokes the input callback and uses ordinary commitment" do
      assert {:ok, updated} =
               Interpreter.complete_cast_with_input(
                 game_state(50, %{29 => 1}),
                 29,
                 1,
                 :self,
                 "hello"
               )

      assert_received {:input_cast, "hello"}
      assert updated.stats.current_state.sp == 40
      assert Map.has_key?(updated.skill_cooldowns, 29)
    end

    test "completion fully revalidates and commits nothing after cooldown lands" do
      initial = game_state(50, %{29 => 1})
      assert :ok = Interpreter.preflight_cast(initial, 29, 1, :self)

      blocked = %{
        initial
        | skill_cooldowns: %{29 => System.monotonic_time(:millisecond) + 10_000}
      }

      assert {:error, :on_cooldown} =
               Interpreter.complete_cast_with_input(blocked, 29, 1, :self, "hello")

      assert blocked.stats.current_state.sp == 50
      refute_received {:input_cast, _input}
    end

    test "skills without the input callback fall back to their ordinary callback" do
      stub(Catalog, :active_module_for, fn :input_aware -> {:ok, OriginAwareSkill} end)

      assert {:ok, _updated} =
               Interpreter.complete_cast_with_input(
                 game_state(50, %{29 => 1}),
                 29,
                 1,
                 :self,
                 "ignored"
               )

      assert_received {:cast_origin, :normal}
    end
  end

  test "targeting another unit on a self-only skill returns :invalid_target" do
    stub(Catalog, :by_id, fn 29 ->
      {:ok,
       %Definition{
         id: 29,
         name: :al_incagi,
         display_name: "Self Test",
         max_level: 10,
         target_type: :self,
         range: 9,
         sp_cost: List.duplicate(9, 10)
       }}
    end)

    assert {:error, :invalid_target} =
             Interpreter.cast(game_state(100, %{29 => 1}), 29, 1, {:unit, 2000})
  end

  test "ordinary enemy skills reject corpse targets before charging SP" do
    corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

    Mimic.copy(TargetResolver)
    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), corpse, :player} end)

    assert {:error, :target_dead} =
             Interpreter.cast(game_state(100, %{6 => 1}), 6, 1, {:unit, 2_000})
  end

  test "ordinary ally and target-any skills reject corpse targets" do
    corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

    Mimic.copy(TargetResolver)
    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), corpse, :player} end)

    for target_type <- [:target_ally, :target_any] do
      stub(Catalog, :by_id, fn 29 ->
        {:ok, %{definition_with_cooldown([]) | target_type: target_type}}
      end)

      assert {:error, :target_dead} =
               Interpreter.cast(game_state(100, %{29 => 1}), 29, 1, {:unit, 2_000})
    end
  end

  test "a corpse-target skill accepts a nearby corpse" do
    corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

    Mimic.copy(TargetResolver)
    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), corpse, :player} end)
    stub(Combat, :resolve_target_position, fn 2_000 -> {:ok, :player, {14, 10, "prontera"}} end)
    stub(Catalog, :by_id, fn 6 -> {:ok, unit_definition(:target_corpse, 5)} end)
    stub(SmProvoke, :cast, fn caster, {:unit, 2_000}, 1, _definition -> {:ok, caster} end)

    assert {:ok, _} = Interpreter.cast(game_state(100, %{6 => 1}), 6, 1, {:unit, 2_000})
  end

  test "a resurrection-target skill accepts a nearby player corpse" do
    corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

    Mimic.copy(TargetResolver)
    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), corpse, :player} end)
    stub(Combat, :resolve_target_position, fn 2_000 -> {:ok, :player, {14, 10, "prontera"}} end)
    stub(Catalog, :by_id, fn 6 -> {:ok, unit_definition(:target_resurrection, 5)} end)
    stub(SmProvoke, :cast, fn caster, {:unit, 2_000}, 1, _definition -> {:ok, caster} end)

    assert {:ok, _} = Interpreter.cast(game_state(100, %{6 => 1}), 6, 1, {:unit, 2_000})
  end

  test "a corpse-target skill rejects a living target" do
    living = %PlayerState{action_state: :idle, stats: %{current_state: %{hp: 100}}}

    Mimic.copy(TargetResolver)
    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), living, :player} end)
    stub(Catalog, :by_id, fn 6 -> {:ok, unit_definition(:target_corpse, 5)} end)

    assert {:error, :invalid_target} =
             Interpreter.cast(game_state(100, %{6 => 1}), 6, 1, {:unit, 2_000})
  end

  test "a corpse-target skill returns a typed error when the target session exits during resolution" do
    Mimic.copy(TargetResolver)
    stub(TargetResolver, :resolve, fn 2_000 -> exit(:shutdown) end)
    stub(Catalog, :by_id, fn 6 -> {:ok, unit_definition(:target_corpse, 5)} end)

    assert {:error, :target_not_found} =
             Interpreter.cast(game_state(100, %{6 => 1}), 6, 1, {:unit, 2_000})
  end

  test "a corpse-target skill rejects an out-of-range corpse" do
    corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

    Mimic.copy(TargetResolver)
    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), corpse, :player} end)
    stub(Combat, :resolve_target_position, fn 2_000 -> {:ok, :player, {20, 10, "prontera"}} end)
    stub(Catalog, :by_id, fn 6 -> {:ok, unit_definition(:target_corpse, 5)} end)

    assert {:error, :out_of_range} =
             Interpreter.cast(game_state(100, %{6 => 1}), 6, 1, {:unit, 2_000})
  end

  test "happy path applies the effect and deducts SP" do
    stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _params -> :ok end)

    gs = game_state(100, %{29 => 1})
    assert {:ok, updated} = Interpreter.cast(gs, 29, 1, :self)
    assert updated.stats.current_state.sp == 100 - 18
  end

  test "all-SP costs leave pre-drain SP available to the effect" do
    definition = %Definition{
      id: 29,
      name: :cost_skill,
      display_name: "Cost Skill",
      max_level: 1,
      target_type: :self,
      sp_cost: [:all]
    }

    stub(Catalog, :by_id, fn 29 -> {:ok, definition} end)
    stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, StaticCostSkill} end)

    assert {:ok, updated} = Interpreter.cast(game_state(50, %{29 => 1}), 29, 1, :self)
    assert_received {:cost_skill_sp, 50}
    assert updated.stats.current_state.sp == 0
  end

  test "prepares an instant dynamic cost once before commitment" do
    definition = %Definition{
      id: 29,
      name: :cost_skill,
      display_name: "Cost Skill",
      max_level: 1,
      target_type: :self
    }

    stub(Catalog, :by_id, fn 29 -> {:ok, definition} end)
    stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, DynamicCostSkill} end)

    Process.put(:interpreter_test_dynamic_sp, 10)
    gs = game_state(50, %{29 => 1})
    assert {:ok, updated} = Interpreter.cast(gs, 29, 1, :self)

    assert_received {:dynamic_cost_prepared, 10}
    refute_received {:dynamic_cost_prepared, 10}
    assert updated.stats.current_state.sp == 40
  end

  test "re-runs a dynamic cost at completion before applying its effect" do
    definition = %Definition{
      id: 29,
      name: :cost_skill,
      display_name: "Cost Skill",
      max_level: 1,
      target_type: :self,
      cast_time: [1_000]
    }

    stub(Catalog, :by_id, fn 29 -> {:ok, definition} end)
    stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, DynamicCostSkill} end)

    Process.put(:interpreter_test_dynamic_sp, 10)
    started = game_state(50, %{29 => 1})
    assert {:casting, ^started, _info} = Interpreter.begin_cast(started, 29, 1, :self)
    assert_received {:dynamic_cost_prepared, 10}

    Process.put(:interpreter_test_dynamic_sp, 60)

    assert {:error, :insufficient_sp} =
             Interpreter.complete_cast(started, 29, 1, :self)

    assert_received {:dynamic_cost_prepared, 60}
    refute_received {:dynamic_cost_prepared, 60}
    refute_received {:cost_skill_sp, _}
  end

  test "rebuilds completion context from the caster's current SP" do
    definition = %Definition{
      id: 29,
      name: :cost_skill,
      display_name: "Cost Skill",
      max_level: 1,
      target_type: :self,
      sp_cost: [10],
      cast_time: [1_000]
    }

    stub(Catalog, :by_id, fn 29 -> {:ok, definition} end)
    stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, StaticCostSkill} end)

    started = game_state(50, %{29 => 1})
    assert {:casting, ^started, _info} = Interpreter.begin_cast(started, 29, 1, :self)

    depleted = put_in(started.stats.current_state.sp, 5)
    assert {:error, :insufficient_sp} = Interpreter.complete_cast(depleted, 29, 1, :self)
    refute_received {:cost_skill_sp, _}
  end

  test "rejects a dynamic cost with nil SP before the effect runs" do
    definition = %Definition{
      id: 29,
      name: :cost_skill,
      display_name: "Cost Skill",
      max_level: 1,
      target_type: :self
    }

    stub(Catalog, :by_id, fn 29 -> {:ok, definition} end)
    stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, DynamicCostSkill} end)

    Process.put(:interpreter_test_dynamic_sp, nil)

    assert {:error, :invalid_cost} =
             Interpreter.cast(game_state(50, %{29 => 1}), 29, 1, :self)

    assert_received {:dynamic_cost_prepared, nil}
    refute_received {:cost_skill_sp, _}
  end

  test "rejects invalid dynamic costs before the effect runs" do
    definition = %Definition{
      id: 29,
      name: :cost_skill,
      display_name: "Cost Skill",
      max_level: 1,
      target_type: :self
    }

    stub(Catalog, :by_id, fn 29 -> {:ok, definition} end)
    stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, MalformedCostSkill} end)

    for dynamic_cost <- [nil, %{}, %Cost{hp: -1}, %Cost{sp: :all}, %Cost{spheres: -1}] do
      Process.put(:interpreter_test_dynamic_cost, dynamic_cost)

      assert {:error, :invalid_cost} = Interpreter.cast(game_state(50, %{29 => 1}), 29, 1, :self)
      refute_received :malformed_cost_effect
    end
  end

  test "applies a prepared sphere cost after an effect changes the returned state" do
    definition = %Definition{
      id: 29,
      name: :cost_skill,
      display_name: "Cost Skill",
      max_level: 1,
      target_type: :self,
      sp_cost: [0],
      sphere_cost: [1]
    }

    stub(Catalog, :by_id, fn 29 -> {:ok, definition} end)
    stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, ResourceChangingCostSkill} end)

    {spheres, _entry} = SpiritSpheres.summon(SpiritSpheres.new(), 60_000, 5)
    game_state = Map.put(game_state(50, %{29 => 1}), :spirit_spheres, spheres)

    assert {:ok, updated} = Interpreter.cast(game_state, 29, 1, :self)
    assert_received :resource_changing_effect
    assert SpiritSpheres.count(updated.spirit_spheres) == 0
  end

  test "re-validates active requirements at completion before the effect runs" do
    definition = %Definition{
      id: 29,
      name: :cost_skill,
      display_name: "Cost Skill",
      max_level: 1,
      target_type: :self,
      sp_cost: [0],
      cast_time: [1_000]
    }

    stub(Catalog, :by_id, fn 29 -> {:ok, definition} end)
    stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, CompletionValidationSkill} end)

    Process.put(:interpreter_test_allow_cast?, true)
    starting = game_state(50, %{29 => 1})
    assert {:casting, ^starting, _info} = Interpreter.begin_cast(starting, 29, 1, :self)

    Process.put(:interpreter_test_allow_cast?, false)

    assert {:error, :requirements_changed} =
             Interpreter.complete_cast(starting, 29, 1, :self)

    refute_received :completion_validation_effect
  end

  test "commits fixed HP, SP, and sphere costs only after the effect" do
    definition = %Definition{
      id: 29,
      name: :cost_skill,
      display_name: "Cost Skill",
      max_level: 1,
      target_type: :self,
      hp_cost: [10],
      sp_cost: [20],
      sphere_cost: [2]
    }

    stub(Catalog, :by_id, fn 29 -> {:ok, definition} end)
    stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, StaticCostSkill} end)

    spheres =
      Enum.reduce(1..2, SpiritSpheres.new(), fn _, acc ->
        {next, _entry} = SpiritSpheres.summon(acc, 60_000, 5)
        next
      end)

    game_state = Map.put(game_state(50, %{29 => 1}), :spirit_spheres, spheres)

    assert {:ok, updated} = Interpreter.cast(game_state, 29, 1, :self)
    assert_received {:cost_skill_sp, 50}
    assert updated.stats.current_state.hp == 90
    assert updated.stats.current_state.sp == 30
    assert SpiritSpheres.count(updated.spirit_spheres) == 0
  end

  test "preserves a deferred descriptor without committing costs or delay" do
    definition = %Definition{
      id: 29,
      name: :cost_skill,
      display_name: "Cost Skill",
      max_level: 1,
      target_type: :self,
      hp_cost: [10],
      sp_cost: [20],
      after_cast_delay: [1_000],
      cooldown: [1_000]
    }

    stub(Catalog, :by_id, fn 29 -> {:ok, definition} end)
    stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, DeferredCostSkill} end)

    game_state = game_state(50, %{29 => 1})

    assert {:deferred, ^game_state,
            %Interpreter.Deferred{
              effect: :spirit_action,
              cost: %Cost{hp: 10, sp: 20},
              skill_id: 29,
              level: 1,
              target: :self
            } = deferred} = Interpreter.cast(game_state, 29, 1, :self)

    assert {:error, :insufficient_sp} =
             Interpreter.settle_deferred(
               put_in(game_state.stats.current_state.sp, 10),
               deferred
             )

    assert {:ok, settled} = Interpreter.settle_deferred(game_state, deferred)
    assert settled.stats.current_state.hp == 90
    assert settled.stats.current_state.sp == 30
    assert settled.skill_cooldowns[29] > System.monotonic_time(:millisecond)
    assert settled.act_delay_until > System.monotonic_time(:millisecond)
  end

  defp definition_with_cooldown(cooldown) do
    %Definition{
      id: 29,
      name: :al_incagi,
      display_name: "Increase AGI",
      max_level: 10,
      target_type: :target_ally,
      range: 9,
      sp_cost: [18, 21, 24, 27, 30, 33, 36, 39, 42, 45],
      cooldown: cooldown
    }
  end

  test "second cast within the cooldown window returns :on_cooldown" do
    stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _params -> :ok end)
    stub(Catalog, :by_id, fn 29 -> {:ok, definition_with_cooldown([10_000])} end)

    gs = game_state(100, %{29 => 1})

    assert {:ok, updated} = Interpreter.cast(gs, 29, 1, :self)
    assert {:error, :on_cooldown} = Interpreter.cast(updated, 29, 1, :self)
  end

  test "casting a passive skill returns :passive_skill" do
    stub(Catalog, :by_id, fn 2 ->
      {:ok,
       %Definition{
         id: 2,
         name: :sm_sword,
         display_name: "Sword Mastery",
         max_level: 10,
         target_type: :passive
       }}
    end)

    assert {:error, :passive_skill} =
             Interpreter.cast(game_state(100, %{2 => 5}), 2, 5, :self)
  end

  test "zero-duration cooldown casts repeatedly and writes no entry" do
    stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _params -> :ok end)
    stub(Catalog, :by_id, fn 29 -> {:ok, definition_with_cooldown([])} end)

    gs = game_state(100, %{29 => 1})

    assert {:ok, updated} = Interpreter.cast(gs, 29, 1, :self)
    assert updated.skill_cooldowns == %{}
    assert {:ok, _} = Interpreter.cast(updated, 29, 1, :self)
  end

  test "targeted skill cast beyond definition.range returns :out_of_range" do
    stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(5)} end)

    stub(SpatialIndex, :get_unit_position, fn
      :player, 9999 -> {:error, :not_found}
      :mob, 9999 -> {:ok, {20, 20, "prontera"}}
    end)

    gs = game_state(100, %{6 => 1})
    assert {:error, :out_of_range} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
  end

  test "targeted skill cast within definition.range proceeds to behavior" do
    stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(5)} end)
    stub_provoke_target(9999)

    stub(SpatialIndex, :get_unit_position, fn
      :player, 9999 -> {:error, :not_found}
      :mob, 9999 -> {:ok, {14, 10, "prontera"}}
    end)

    stub(StatusInterpreter, :apply_status, fn _type, _id, _status, _params -> :ok end)

    gs = game_state(100, %{6 => 1})
    assert {:ok, _} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
  end

  test "a melee skill (range: -1) resolves to the weapon range: adjacent target is in range" do
    stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(-1)} end)
    stub_provoke_target(9999)

    stub(SpatialIndex, :get_unit_position, fn
      :player, 9999 -> {:error, :not_found}
      :mob, 9999 -> {:ok, {11, 10, "prontera"}}
    end)

    stub(StatusInterpreter, :apply_status, fn _type, _id, _status, _params -> :ok end)

    gs = game_state(100, %{6 => 1})
    assert {:ok, _} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
  end

  test "a melee skill (range: -1) resolves to the weapon range: a 3-cell target is out of range" do
    stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(-1)} end)

    stub(SpatialIndex, :get_unit_position, fn
      :player, 9999 -> {:error, :not_found}
      :mob, 9999 -> {:ok, {13, 10, "prontera"}}
    end)

    gs = game_state(100, %{6 => 1})
    assert {:error, :out_of_range} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
  end

  test "a per-level range list resolves the range for the cast level, not the widest level" do
    stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition([3, 5, 7, 9, 11])} end)
    stub_provoke_target(9999)

    stub(SpatialIndex, :get_unit_position, fn
      :player, 9999 -> {:error, :not_found}
      :mob, 9999 -> {:ok, {17, 10, "prontera"}}
    end)

    stub(StatusInterpreter, :apply_status, fn _type, _id, _status, _params -> :ok end)

    gs = game_state(100, %{6 => 3})
    assert {:ok, _} = Interpreter.cast(gs, 6, 3, {:unit, 9999})
  end

  test "a per-level range list rejects a cast one cell beyond the cast level's range" do
    stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition([3, 5, 7, 9, 11])} end)

    stub(SpatialIndex, :get_unit_position, fn
      :player, 9999 -> {:error, :not_found}
      :mob, 9999 -> {:ok, {18, 10, "prontera"}}
    end)

    gs = game_state(100, %{6 => 3})
    assert {:error, :out_of_range} = Interpreter.cast(gs, 6, 3, {:unit, 9999})
  end

  test "a per-level range list at a lower level does not fall back to the widest level's range" do
    stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition([3, 5, 7, 9, 11])} end)

    stub(SpatialIndex, :get_unit_position, fn
      :player, 9999 -> {:error, :not_found}
      :mob, 9999 -> {:ok, {14, 10, "prontera"}}
    end)

    gs = game_state(100, %{6 => 1})
    assert {:error, :out_of_range} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
  end

  describe "effective_range/3" do
    test "resolves a flat range regardless of level" do
      definition = enemy_definition(9)
      gs = game_state(100, %{})

      assert Interpreter.effective_range(definition, gs, 1) == 9
      assert Interpreter.effective_range(definition, gs, 10) == 9
    end

    test "resolves a per-level list at the cast level" do
      definition = enemy_definition([3, 5, 7, 9, 11])
      gs = game_state(100, %{})

      assert Interpreter.effective_range(definition, gs, 1) == 3
      assert Interpreter.effective_range(definition, gs, 3) == 7
      assert Interpreter.effective_range(definition, gs, 5) == 11
    end

    test "resolves a -1 sentinel to the caster's weapon range" do
      definition = enemy_definition(-1)
      gs = game_state(100, %{})

      assert Interpreter.effective_range(definition, gs, 1) == 1
    end
  end

  test "an enemy skill targeting another player is rejected as :invalid_target" do
    stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(9)} end)

    stub(SpatialIndex, :get_unit_position, fn
      :mob, 9999 -> {:error, :not_found}
      :player, 9999 -> {:ok, {12, 10, "prontera"}}
    end)

    gs = game_state(100, %{6 => 1})
    assert {:error, :invalid_target} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
  end

  test "an enemy skill rejects a player target when a mob shares its ID" do
    stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(9)} end)

    stub(SpatialIndex, :get_unit_position, fn
      :mob, 9999 -> {:ok, {12, 10, "prontera"}}
      :player, 9999 -> {:ok, {12, 10, "prontera"}}
    end)

    gs = game_state(100, %{6 => 1})
    assert {:error, :invalid_target} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
  end

  test "an enemy skill targeting a mob on another map returns :different_map" do
    stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(9)} end)

    stub(SpatialIndex, :get_unit_position, fn
      :player, 9999 -> {:error, :not_found}
      :mob, 9999 -> {:ok, {12, 10, "geffen"}}
    end)

    gs = game_state(100, %{6 => 1})
    assert {:error, :different_map} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
  end

  describe "skill-unit targets (Ice Wall, etc.)" do
    test "an enemy skill accepts a targetable skill-unit cell and proceeds to behavior" do
      stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(9)} end)

      target_id = SkillUnitId.first()
      # Resolve returns the real skill-unit type; sm_provoke must carry that
      # unit_type through to apply_status (not re-derive it via caster-only helpers).
      stub(TargetResolver, :resolve, fn ^target_id ->
        {:ok, self(), struct(MobState, instance_id: target_id, hp: 1, max_hp: 1), :skill_unit}
      end)

      stub(Combat, :resolve_target_position, fn ^target_id ->
        {:ok, :skill_unit, {14, 10, "prontera"}}
      end)

      stub(StatusInterpreter, :apply_status, fn _type, _id, _status, _params -> :ok end)

      gs = game_state(100, %{6 => 1})
      assert {:ok, _} = Interpreter.cast(gs, 6, 1, {:unit, target_id})
    end

    test "an enemy skill fizzles with :target_not_found for an unresolved skill-unit id" do
      stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(9)} end)

      target_id = SkillUnitId.first()
      stub(Combat, :resolve_target_position, fn ^target_id -> {:error, :target_not_found} end)

      gs = game_state(100, %{6 => 1})
      assert {:error, :target_not_found} = Interpreter.cast(gs, 6, 1, {:unit, target_id})
    end

    test "an enemy skill still accepts a mob target routed through Combat.resolve_target_position" do
      stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(9)} end)
      stub_provoke_target(9999)
      stub(Combat, :resolve_target_position, fn 9999 -> {:ok, :mob, {14, 10, "prontera"}} end)
      stub(StatusInterpreter, :apply_status, fn _type, _id, _status, _params -> :ok end)

      gs = game_state(100, %{6 => 1})
      assert {:ok, _} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
    end

    test "an enemy skill still rejects a player target routed through Combat.resolve_target_position" do
      stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(9)} end)
      stub(Combat, :resolve_target_position, fn 9999 -> {:ok, :player, {14, 10, "prontera"}} end)

      gs = game_state(100, %{6 => 1})
      assert {:error, :invalid_target} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
    end
  end

  test ":self skills bypass the range check" do
    stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _params -> :ok end)

    gs = game_state(100, %{29 => 1})
    assert {:ok, _} = Interpreter.cast(gs, 29, 1, :self)
  end

  defp unit_definition(target_type, range) do
    %Definition{
      id: 6,
      name: :sm_provoke,
      display_name: "Unit Target Test",
      max_level: 10,
      target_type: target_type,
      damage_type: :no_damage,
      range: range,
      sp_cost: List.duplicate(9, 10)
    }
  end

  test ":target_any skill accepts a unit target and proceeds to behavior" do
    stub(Catalog, :by_id, fn 6 -> {:ok, unit_definition(:target_any, 9)} end)
    stub(SpatialIndex, :get_unit_position, fn :player, 9999 -> {:ok, {14, 10, "prontera"}} end)
    stub(SmProvoke, :cast, fn caster, {:unit, 9999}, 1, _definition -> {:ok, caster} end)

    gs = game_state(100, %{6 => 1})
    assert {:ok, _} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
  end

  test ":target_any skill accepts :self target" do
    stub(Catalog, :by_id, fn 6 -> {:ok, unit_definition(:target_any, 9)} end)
    stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

    gs = game_state(100, %{6 => 1})
    assert {:ok, _} = Interpreter.cast(gs, 6, 1, :self)
  end

  test ":target_any skill rejects an out-of-range unit target" do
    stub(Catalog, :by_id, fn 6 -> {:ok, unit_definition(:target_any, 5)} end)

    stub(SpatialIndex, :get_unit_position, fn
      :player, 9999 -> {:error, :not_found}
      :mob, 9999 -> {:ok, {20, 20, "prontera"}}
    end)

    gs = game_state(100, %{6 => 1})
    assert {:error, :out_of_range} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
  end

  test "ally skill cast on another unit proceeds to behavior" do
    stub(Catalog, :by_id, fn 6 -> {:ok, unit_definition(:target_ally, 9)} end)
    stub_provoke_target(9999)
    stub(SpatialIndex, :get_unit_position, fn :player, 9999 -> {:ok, {14, 10, "prontera"}} end)
    stub(StatusInterpreter, :apply_status, fn _type, _id, _status, _params -> :ok end)

    gs = game_state(100, %{6 => 1})
    assert {:ok, _} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
  end

  defp ground_definition(range) do
    %Definition{
      id: 6,
      name: :sm_provoke,
      display_name: "Ground Test",
      max_level: 10,
      target_type: :ground,
      damage_type: :no_damage,
      range: range,
      sp_cost: List.duplicate(9, 10)
    }
  end

  defp put_walkable_map do
    map = MapData.new("prontera", 20, 20)
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", map})
  end

  test "ground casts allow Ice Wall contributions" do
    put_walkable_map()
    stub(Catalog, :by_id, fn 6 -> {:ok, ground_definition(9)} end)
    stub(SmProvoke, :cast, fn caster, {:ground, 12, 12}, 1, _definition -> {:ok, caster} end)

    gs = game_state(100, %{6 => 1})
    :ok = Cell.put("prontera", 12, 12, :icewall, 1, blocks_movement: true)

    assert {:ok, _} = Interpreter.cast(gs, 6, 1, {:ground, 12, 12})
  end

  test "ground cast succeeds for a target_type: :ground definition" do
    put_walkable_map()
    stub(Catalog, :by_id, fn 6 -> {:ok, ground_definition(9)} end)
    stub(SmProvoke, :cast, fn caster, {:ground, 12, 12}, 1, _definition -> {:ok, caster} end)

    gs = game_state(100, %{6 => 1})
    assert {:ok, _} = Interpreter.cast(gs, 6, 1, {:ground, 12, 12})
  end

  test "ground cast on a non-ground definition returns :invalid_target" do
    stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(9)} end)

    gs = game_state(100, %{6 => 1})
    assert {:error, :invalid_target} = Interpreter.cast(gs, 6, 1, {:ground, 12, 12})
  end

  test "ground cast beyond definition.range returns :out_of_range" do
    stub(Catalog, :by_id, fn 6 -> {:ok, ground_definition(5)} end)

    gs = game_state(100, %{6 => 1})
    assert {:error, :out_of_range} = Interpreter.cast(gs, 6, 1, {:ground, 50, 50})
  end

  test "ground cast onto a non-walkable cell returns :invalid_target" do
    map =
      MapData.new("prontera", 20, 20)
      |> MapData.set_cell(12, 12, GatType.wall())

    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", map})
    stub(Catalog, :by_id, fn 6 -> {:ok, ground_definition(9)} end)

    gs = game_state(100, %{6 => 1})
    assert {:error, :invalid_target} = Interpreter.cast(gs, 6, 1, {:ground, 12, 12})
  end

  # A self-targeted instant skill: target_ally bypasses range, cast_time [0] is
  # instant. SmProvoke is the catalog-registered behavior for id 6.
  defp instant_definition do
    %Definition{
      id: 6,
      name: :sm_provoke,
      display_name: "Instant Test",
      max_level: 10,
      target_type: :target_ally,
      damage_type: :no_damage,
      element: :neutral,
      range: 9,
      sp_cost: List.duplicate(9, 10),
      cast_time: [0],
      cooldown: [5_000]
    }
  end

  describe "dynamic cast-time seam" do
    @timing_definition %Definition{
      id: 29,
      name: :cost_skill,
      display_name: "Cost Skill",
      max_level: 1,
      target_type: :self,
      sp_cost: [0],
      cast_time: [1_000],
      fixed_cast_time: [400]
    }

    test "an implementing skill can zero its cast time from context" do
      stub(Catalog, :by_id, fn 29 -> {:ok, @timing_definition} end)
      stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, DynamicCastTimeSkill} end)

      Process.put(:interpreter_test_instant_cast?, true)
      assert {:instant, _gs} = Interpreter.begin_cast(game_state(50, %{29 => 1}), 29, 1, :self)

      Process.put(:interpreter_test_instant_cast?, false)

      assert {:casting, _gs, info} =
               Interpreter.begin_cast(game_state(50, %{29 => 1}), 29, 1, :self)

      assert info.fixed == 400
      assert info.total > 400
    end

    test "a non-implementing skill keeps its declared cast time byte-identical" do
      stub(Catalog, :by_id, fn 29 -> {:ok, @timing_definition} end)
      stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, StaticCostSkill} end)

      assert {:casting, _gs, info} =
               Interpreter.begin_cast(game_state(50, %{29 => 1}), 29, 1, :self)

      expected =
        CastTime.compute(@timing_definition, 1, %{
          dex: 1,
          int: 1,
          varcast_reductions: [],
          varcast_rate: 0,
          fixed_cast: 0
        })

      assert info.fixed == expected.fixed
      assert info.total == expected.total
    end
  end

  describe "begin_cast/4" do
    test "instant skill runs the behavior, deducts SP, and sets the cooldown" do
      stub(Catalog, :by_id, fn 6 -> {:ok, instant_definition()} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      gs = game_state(100, %{6 => 1})

      assert {:instant, updated} = Interpreter.begin_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 100 - 9
      assert Map.has_key?(updated.skill_cooldowns, 6)
    end

    # al_incagi (id 29) is the real catalog skill with cast_time 800ms and a
    # non-ground :self target, exercising the timed branch without a Catalog stub.
    test "timed skill returns :casting without deducting SP or setting a cooldown" do
      reject(&StatusInterpreter.apply_status/4)

      gs = game_state(100, %{29 => 1})

      assert {:casting, returned, info} = Interpreter.begin_cast(gs, 29, 1, :self)
      assert returned == gs
      assert returned.stats.current_state.sp == 100
      assert returned.skill_cooldowns == %{}

      assert info.skill_id == 29
      assert info.level == 1
      assert info.target == :self
      assert info.element == :neutral
      assert info.total > 0
      assert info.fixed >= 0
      assert info.fixed <= info.total
    end

    test "insufficient SP returns :insufficient_sp before computing cast time" do
      reject(&StatusInterpreter.apply_status/4)

      assert {:error, :insufficient_sp} =
               Interpreter.begin_cast(game_state(1, %{29 => 1}), 29, 1, :self)
    end

    test "applies a status :cast_time_reduction to the variable cast, leaving fixed untouched" do
      reject(&StatusInterpreter.apply_status/4)
      gs = game_state(100, %{29 => 1})

      stub(StatusStorage, :get_unit_statuses, fn :player, 1000 -> [] end)
      assert {:casting, _gs, unreduced} = Interpreter.begin_cast(gs, 29, 1, :self)

      stub(StatusStorage, :get_unit_statuses, fn :player, 1000 ->
        [%StatusEntry{state: %{cast_time_reduction: 45}}]
      end)

      assert {:casting, _gs, reduced} = Interpreter.begin_cast(gs, 29, 1, :self)

      assert reduced.fixed == unreduced.fixed
      assert reduced.total - reduced.fixed == round((unreduced.total - unreduced.fixed) * 0.55)
      assert reduced.total < unreduced.total
    end

    test "Suffragium reduces variable cast time and persists through the Renewal cast lifecycle" do
      gs = game_state(100, %{29 => 1})

      stub(UnitRegistry, :get_unit_info, fn :player, 1000 -> {:ok, %{stats: gs.stats}} end)

      assert {:casting, _gs, unreduced} = Interpreter.begin_cast(gs, 29, 1, :self)

      assert {:ok, suffragium} =
               Suffragium.on_apply(
                 {:player, 1000},
                 %StatusEntry{type: :sc_suffragium, val1: 3, state: %{}},
                 %{}
               )

      :ok =
        StatusStorage.apply_status(:player, 1000, :sc_suffragium,
          duration: 30_000,
          val1: 3,
          state: suffragium.state
        )

      assert {:casting, _gs, reduced} = Interpreter.begin_cast(gs, 29, 1, :self)
      assert reduced.fixed == unreduced.fixed
      assert reduced.total - reduced.fixed == round((unreduced.total - unreduced.fixed) * 0.8)

      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _params -> :ok end)

      assert {:ok, _updated} = Interpreter.complete_cast(gs, 29, 1, :self)
      assert StatusStorage.has_status?(:player, 1000, :sc_suffragium)
    end

    test "composes multiple status cast reductions multiplicatively, not additively" do
      reject(&StatusInterpreter.apply_status/4)
      gs = game_state(100, %{29 => 1})

      stub(StatusStorage, :get_unit_statuses, fn :player, 1000 -> [] end)
      assert {:casting, _gs, unreduced} = Interpreter.begin_cast(gs, 29, 1, :self)

      stub(StatusStorage, :get_unit_statuses, fn :player, 1000 ->
        [
          %StatusEntry{state: %{cast_time_reduction: 30}},
          %StatusEntry{state: %{cast_time_reduction: 15}}
        ]
      end)

      assert {:casting, _gs, reduced} = Interpreter.begin_cast(gs, 29, 1, :self)

      unreduced_variable = unreduced.total - unreduced.fixed
      reduced_variable = reduced.total - reduced.fixed

      # multiplicative 0.70 * 0.85 = 0.595 keeps MORE cast than the additive
      # 30 + 15 = 45% (0.55) would, and never more than either factor alone
      assert reduced_variable == round(unreduced_variable * 0.7 * 0.85)
      assert reduced_variable > round(unreduced_variable * 0.55)
    end
  end

  describe "sp_cost_rate" do
    test "a negative sp_cost_rate reduces the SP deducted at castend" do
      stub(Catalog, :by_id, fn 6 -> {:ok, instant_definition()} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 ->
        %{sp_cost_rate: -50}
      end)

      gs = game_state(100, %{6 => 1})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      # base cost 9, -50% -> div(9 * 50, 100) = 4; single application
      assert updated.stats.current_state.sp == 100 - 4
    end

    test "floors the SP cost multiplier at 0 when the reduction exceeds 100%" do
      stub(Catalog, :by_id, fn 6 -> {:ok, instant_definition()} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 ->
        %{sp_cost_rate: -150}
      end)

      gs = game_state(100, %{6 => 1})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 100
    end

    test "the reduced cost gates check_sp at validate time (not the raw cost)" do
      stub(Catalog, :by_id, fn 6 -> {:ok, instant_definition()} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 ->
        %{sp_cost_rate: -50}
      end)

      # 5 SP is below the raw cost 9 but at/above the reduced cost 4
      gs = game_state(5, %{6 => 1})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 5 - 4
    end
  end

  describe "varcast_rate" do
    test "a negative varcast_rate shortens the timed cast" do
      reject(&StatusInterpreter.apply_status/4)
      gs = game_state(100, %{29 => 1})

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{} end)
      assert {:casting, _gs, baseline} = Interpreter.begin_cast(gs, 29, 1, :self)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 ->
        %{varcast_rate: -50}
      end)

      assert {:casting, _gs, reduced} = Interpreter.begin_cast(gs, 29, 1, :self)

      assert reduced.fixed == baseline.fixed
      assert reduced.total - reduced.fixed == round((baseline.total - baseline.fixed) * 0.5)
      assert reduced.total < baseline.total
    end
  end

  describe "equipment {:skill_cooldown, id}" do
    setup do
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _params -> :ok end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition_with_cooldown([10_000])} end)
      :ok
    end

    test "a negative equipment cooldown delta shortens only the named skill" do
      gs = game_state(100, %{29 => 1}, %{{:skill_cooldown, 29} => -3_000})

      before = System.monotonic_time(:millisecond)
      assert {:ok, updated} = Interpreter.complete_cast(gs, 29, 1, :self)
      after_t = System.monotonic_time(:millisecond)

      expires = updated.skill_cooldowns[29]
      assert expires >= before + 7_000
      assert expires <= after_t + 7_000
    end

    test "a cooldown delta keyed on another skill leaves this skill's cooldown untouched" do
      gs = game_state(100, %{29 => 1}, %{{:skill_cooldown, 999} => -9_000})

      before = System.monotonic_time(:millisecond)
      assert {:ok, updated} = Interpreter.complete_cast(gs, 29, 1, :self)
      after_t = System.monotonic_time(:millisecond)

      expires = updated.skill_cooldowns[29]
      assert expires >= before + 10_000
      assert expires <= after_t + 10_000
    end

    test "an over-large negative delta floors the cooldown at 0 and writes no entry" do
      gs = game_state(100, %{29 => 1}, %{{:skill_cooldown, 29} => -20_000})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 29, 1, :self)
      assert updated.skill_cooldowns == %{}
    end

    test "an empty equipment map leaves the base cooldown unchanged" do
      gs = game_state(100, %{29 => 1}, %{})

      before = System.monotonic_time(:millisecond)
      assert {:ok, updated} = Interpreter.complete_cast(gs, 29, 1, :self)
      after_t = System.monotonic_time(:millisecond)

      expires = updated.skill_cooldowns[29]
      assert expires >= before + 10_000
      assert expires <= after_t + 10_000
    end
  end

  describe "equipment {:skill_use_sp, id}" do
    setup do
      stub(Catalog, :by_id, fn 6 -> {:ok, instant_definition()} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)
      :ok
    end

    test "a flat SP reduction lowers only the named skill's cost" do
      gs = game_state(100, %{6 => 1}, %{{:skill_use_sp, 6} => 3})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 100 - (9 - 3)
    end

    test "an SP reduction keyed on another skill leaves this skill's cost untouched" do
      gs = game_state(100, %{6 => 1}, %{{:skill_use_sp, 999} => 5})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 100 - 9
    end

    test "the flat reduction composes after the :sp_cost_rate percent step" do
      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{sp_cost_rate: -50} end)
      gs = game_state(100, %{6 => 1}, %{{:skill_use_sp, 6} => 3})

      # base 9, -50% -> div(9 * 50, 100) = 4; then flat -3 -> 1
      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 100 - 1
    end

    test "an over-large flat reduction floors the SP cost at 0" do
      gs = game_state(100, %{6 => 1}, %{{:skill_use_sp, 6} => 20})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 100
    end

    test "an empty equipment map leaves the base SP cost unchanged" do
      gs = game_state(100, %{6 => 1}, %{})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 100 - 9
    end
  end

  describe "equipment :sp_cost_rate and {:skill_use_sp_rate, id}" do
    setup do
      stub(Catalog, :by_id, fn 6 -> {:ok, instant_definition()} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)
      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{} end)
      :ok
    end

    test "the global equipment rate lowers every skill's cost" do
      gs = game_state(100, %{6 => 1}, %{sp_cost_rate: -50})

      # base 9, -50% -> div(9 * 50, 100) = 4
      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 100 - 4
    end

    test "a per-skill rate lowers only the named skill's cost" do
      gs = game_state(100, %{6 => 1}, %{{:skill_use_sp_rate, 6} => -50})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 100 - 4
    end

    test "a per-skill rate keyed on another skill leaves this skill's cost untouched" do
      gs = game_state(100, %{6 => 1}, %{{:skill_use_sp_rate, 999} => -50})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 100 - 9
    end

    test "status, global and per-skill rates all sum into one percent step" do
      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{sp_cost_rate: -20} end)

      gs =
        game_state(100, %{6 => 1}, %{{:skill_use_sp_rate, 6} => -20, sp_cost_rate: -20})

      # base 9 at -60% -> div(9 * 40, 100) = 3
      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 100 - 3
    end

    test "ordinary SP resolution applies rates before flat reduction for default and raw bases" do
      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{sp_cost_rate: -10} end)

      gs =
        game_state(100, %{6 => 1}, %{
          {:skill_use_sp_rate, 6} => -10,
          {:skill_use_sp, 6} => 3,
          sp_cost_rate: -10
        })

      definition = instant_definition()

      assert Cost.resolve_sp(gs, definition, 1) == 3
      assert Cost.resolve_sp(gs, definition, 1, 21) == 11
      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 97
    end

    test "a stacked over-100% reduction floors the cost at 0 instead of inverting it" do
      gs = game_state(100, %{6 => 1}, %{{:skill_use_sp_rate, 6} => -150})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 100
    end
  end

  describe "equipment :fixed_cast" do
    test "a negative delta shortens the fixed portion and leaves the variable one alone" do
      reject(&StatusInterpreter.apply_status/4)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{} end)

      assert {:casting, _gs, baseline} =
               Interpreter.begin_cast(game_state(100, %{29 => 1}), 29, 1, :self)

      gs = game_state(100, %{29 => 1}, %{fixed_cast: -100})

      assert {:casting, _gs, reduced} = Interpreter.begin_cast(gs, 29, 1, :self)

      assert reduced.fixed == baseline.fixed - 100
      assert reduced.total == baseline.total - 100
    end

    test "an over-large negative delta floors the fixed portion at 0" do
      reject(&StatusInterpreter.apply_status/4)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{} end)

      assert {:casting, _gs, baseline} =
               Interpreter.begin_cast(game_state(100, %{29 => 1}), 29, 1, :self)

      gs = game_state(100, %{29 => 1}, %{fixed_cast: -100_000})

      assert {:casting, _gs, reduced} = Interpreter.begin_cast(gs, 29, 1, :self)

      assert reduced.fixed == 0
      assert reduced.total == baseline.total - baseline.fixed
    end
  end

  describe "equipment :varcast_rate" do
    test "a negative global rate speeds every skill's cast" do
      reject(&StatusInterpreter.apply_status/4)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{} end)

      assert {:casting, _gs, baseline} =
               Interpreter.begin_cast(game_state(100, %{29 => 1}), 29, 1, :self)

      gs = game_state(100, %{29 => 1}, %{varcast_rate: -40})

      assert {:casting, _gs, reduced} = Interpreter.begin_cast(gs, 29, 1, :self)

      assert reduced.fixed == baseline.fixed
      assert reduced.total - reduced.fixed == round((baseline.total - baseline.fixed) * 0.6)
    end

    test "composes additively with the per-skill rate" do
      reject(&StatusInterpreter.apply_status/4)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{} end)

      assert {:casting, _gs, baseline} =
               Interpreter.begin_cast(game_state(100, %{29 => 1}), 29, 1, :self)

      gs =
        game_state(100, %{29 => 1}, %{{:skill_varcast_rate, 29} => -30, varcast_rate: -20})

      assert {:casting, _gs, reduced} = Interpreter.begin_cast(gs, 29, 1, :self)

      # global -20 + per-skill -30 = -50 -> variable * 0.5
      assert reduced.total - reduced.fixed == round((baseline.total - baseline.fixed) * 0.5)
    end

    test "applies to a skill the per-skill rate does not name" do
      reject(&StatusInterpreter.apply_status/4)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{} end)

      assert {:casting, _gs, baseline} =
               Interpreter.begin_cast(game_state(100, %{29 => 1}), 29, 1, :self)

      gs = game_state(100, %{29 => 1}, %{{:skill_varcast_rate, 999} => -50, varcast_rate: -50})

      assert {:casting, _gs, reduced} = Interpreter.begin_cast(gs, 29, 1, :self)

      assert reduced.total - reduced.fixed == round((baseline.total - baseline.fixed) * 0.5)
    end
  end

  describe "equipment {:skill_varcast_rate, id}" do
    test "composes additively with the status varcast_rate: negative speeds the cast" do
      reject(&StatusInterpreter.apply_status/4)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{} end)

      assert {:casting, _gs, baseline} =
               Interpreter.begin_cast(game_state(100, %{29 => 1}), 29, 1, :self)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{varcast_rate: -25} end)
      gs = game_state(100, %{29 => 1}, %{{:skill_varcast_rate, 29} => -25})

      assert {:casting, _gs, reduced} = Interpreter.begin_cast(gs, 29, 1, :self)

      assert reduced.fixed == baseline.fixed
      # status -25 + equipment -25 = -50 -> variable * 0.5
      assert reduced.total - reduced.fixed == round((baseline.total - baseline.fixed) * 0.5)
    end

    test "a positive equipment rate offsets a negative status rate additively" do
      reject(&StatusInterpreter.apply_status/4)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{} end)

      assert {:casting, _gs, baseline} =
               Interpreter.begin_cast(game_state(100, %{29 => 1}), 29, 1, :self)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{varcast_rate: -50} end)
      gs = game_state(100, %{29 => 1}, %{{:skill_varcast_rate, 29} => 30})

      assert {:casting, _gs, reduced} = Interpreter.begin_cast(gs, 29, 1, :self)

      # status -50 + equipment +30 = -20 -> variable * 0.8
      assert reduced.total - reduced.fixed == round((baseline.total - baseline.fixed) * 0.8)
    end

    test "a varcast rate keyed on another skill leaves this skill's cast untouched" do
      reject(&StatusInterpreter.apply_status/4)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{} end)

      assert {:casting, _gs, baseline} =
               Interpreter.begin_cast(game_state(100, %{29 => 1}), 29, 1, :self)

      gs = game_state(100, %{29 => 1}, %{{:skill_varcast_rate, 999} => -50})
      assert {:casting, _gs, unaffected} = Interpreter.begin_cast(gs, 29, 1, :self)

      assert unaffected.total == baseline.total
    end

    test "an empty equipment map leaves the cast time unchanged" do
      reject(&StatusInterpreter.apply_status/4)

      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1000 -> %{} end)

      assert {:casting, _gs, baseline} =
               Interpreter.begin_cast(game_state(100, %{29 => 1}), 29, 1, :self)

      assert {:casting, _gs, empty} =
               Interpreter.begin_cast(game_state(100, %{29 => 1}, %{}), 29, 1, :self)

      assert empty.total == baseline.total
    end
  end

  describe "complete_cast/4" do
    setup do
      Mimic.copy(TargetResolver)
      Mimic.copy(MobState)
      :ok
    end

    test "deducts SP, runs the behavior, and sets the cooldown" do
      stub(Catalog, :by_id, fn 6 -> {:ok, instant_definition()} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      gs = game_state(100, %{6 => 1})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 100 - 9
      assert Map.has_key?(updated.skill_cooldowns, 6)
    end

    test "keeps completion free of begin-only gates" do
      definition = %Definition{
        id: 6,
        name: :sm_provoke,
        display_name: "Completion Subset",
        max_level: 1,
        target_type: :passive,
        require_weapon: [:musical],
        sp_cost: [0, 0],
        cooldown: [10_000, 10_000]
      }

      stub(Catalog, :by_id, fn 6 -> {:ok, definition} end)
      stub(SmProvoke, :cast, fn caster, :self, 2, _definition -> {:ok, caster} end)

      blocked = %{
        game_state(100, %{})
        | skill_cooldowns: %{6 => System.monotonic_time(:millisecond) + 10_000},
          act_delay_until: System.monotonic_time(:millisecond) + 10_000
      }

      assert {:ok, _updated} = Interpreter.complete_cast(blocked, 6, 2, :self)
    end

    test "completes a timed cast when another effect arms cooldown and action delay" do
      definition = %{instant_definition() | cast_time: [1_000]}
      stub(Catalog, :by_id, fn 6 -> {:ok, definition} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      gs = game_state(100, %{6 => 1})
      assert {:casting, ^gs, _info} = Interpreter.begin_cast(gs, 6, 1, :self)

      delayed = %{
        gs
        | skill_cooldowns: %{6 => System.monotonic_time(:millisecond) + 10_000},
          act_delay_until: System.monotonic_time(:millisecond) + 10_000
      }

      assert {:ok, updated} = Interpreter.complete_cast(delayed, 6, 1, :self)
      assert updated.stats.current_state.sp == 100 - 9
    end

    test "fizzles with :out_of_range and spends no SP when the target moved away" do
      stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(5)} end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 9999 -> {:error, :not_found}
        :mob, 9999 -> {:ok, {20, 20, "prontera"}}
      end)

      gs = game_state(100, %{6 => 1})

      assert {:error, :out_of_range} = Interpreter.complete_cast(gs, 6, 1, {:unit, 9999})
    end

    test "fizzles with :target_not_found and spends no SP when the target is gone" do
      stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(9)} end)
      stub(SpatialIndex, :get_unit_position, fn _type, 9999 -> {:error, :not_found} end)

      gs = game_state(100, %{6 => 1})

      assert {:error, :target_not_found} = Interpreter.complete_cast(gs, 6, 1, {:unit, 9999})
    end

    test "a stale Resurrection corpse session retains SP and its Blue Gemstone" do
      corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}
      gs = resurrection_game_state()

      stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), corpse, :player} end)
      stub(Combat, :resolve_target_position, fn 2_000 -> {:ok, :player, {14, 10, "prontera"}} end)
      stub(PlayerSession, :resurrect, fn _pid, 1_000, 10 -> {:error, :target_not_found} end)

      assert {:error, :target_not_found} =
               Interpreter.complete_cast(gs, 54, 1, {:unit, 2_000})

      assert gs.stats.current_state.sp == 100
      assert %{0 => %InventoryItem{nameid: 717, amount: 1}} = gs.inventory
      assert gs.pending_inventory_persist == []
    end

    test "Into the Abyss waives a Blue Gemstone for Resurrection" do
      corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}
      gs = %{resurrection_game_state() | inventory: %{}}

      :ok = StatusStorage.apply_status(:player, 1000, :sc_intoabyss)
      stub(UnitRegistry, :get_unit_info, fn :player, 1000 -> {:ok, %{stats: %{}}} end)
      stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), corpse, :player} end)
      stub(Combat, :resolve_target_position, fn 2_000 -> {:ok, :player, {14, 10, "prontera"}} end)
      stub(PlayerSession, :resurrect, fn _pid, 1_000, 10 -> :ok end)

      assert {:ok, updated} = Interpreter.complete_cast(gs, 54, 1, {:unit, 2_000})
      assert updated.stats.current_state.sp == 40
      assert updated.inventory == %{}
      assert updated.pending_inventory_persist == []
    end

    test "Into the Abyss neither waives nor spares an Ankle Snare trap" do
      map = MapData.new("prontera", 20, 20)
      :ets.insert(EtsTable.table_for(:map_cache), {"prontera", map})
      :ok = StatusStorage.apply_status(:player, 1000, :sc_intoabyss)

      without_trap = game_state(100, %{117 => 1})

      stub(UnitRegistry, :get_unit_info, fn :player, 1000 -> {:ok, %{stats: %{}}} end)

      assert {:error, :missing_catalyst} =
               Interpreter.complete_cast(without_trap, 117, 1, {:ground, 11, 10})

      with_trap = put_in(without_trap.inventory[0], %InventoryItem{nameid: 1065, amount: 1})

      stub(UnitRegistry, :get_unit_info, fn :player, 1000 ->
        {:ok, %{stats: %{dex: 1, int: 1, base_level: 1}}}
      end)

      assert {:ok, updated} = Interpreter.complete_cast(with_trap, 117, 1, {:ground, 11, 10})
      assert updated.inventory == %{}
      assert length(updated.pending_inventory_persist) == 1
    end

    test "catalyst check and consume resolve the same effective list across item costs" do
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      stub(UnitRegistry, :get_unit_info, fn :player, 1000 -> {:ok, %{stats: %{}}} end)

      for gemstone_id <- [715, 716, 717], trap? <- [false, true], waiver? <- [false, true] do
        item_cost =
          [%{id: gemstone_id, amount: 2}] ++
            if(trap?, do: [%{id: 1065, amount: 1}], else: [])

        definition = %{instant_definition() | item_cost: item_cost}
        stub(Catalog, :by_id, fn 6 -> {:ok, definition} end)

        if waiver? do
          :ok = StatusStorage.apply_status(:player, 1000, :sc_intoabyss)
        else
          :ok = StatusStorage.remove_status(:player, 1000, :sc_intoabyss)
        end

        full_inventory =
          item_cost
          |> Enum.with_index()
          |> Map.new(fn {%{id: id, amount: amount}, index} ->
            {index, %InventoryItem{nameid: id, amount: amount}}
          end)

        gs =
          game_state(100, %{6 => 1})
          |> Map.merge(%{inventory: full_inventory, pending_inventory_persist: []})

        assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)

        assert Inventory.held_amount(updated.inventory, gemstone_id) ==
                 if(waiver?, do: 2, else: 0)

        assert Inventory.held_amount(updated.inventory, 1065) == 0

        empty_inventory = %{gs | inventory: %{}, pending_inventory_persist: []}

        if Interpreter.effective_item_cost(gs, definition) == [] do
          assert {:ok, _updated} = Interpreter.complete_cast(empty_inventory, 6, 1, :self)
        else
          assert {:error, :missing_catalyst} =
                   Interpreter.complete_cast(empty_inventory, 6, 1, :self)
        end
      end
    end

    test "a successful corpse Resurrection charges SP and its Blue Gemstone" do
      corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

      stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), corpse, :player} end)
      stub(Combat, :resolve_target_position, fn 2_000 -> {:ok, :player, {14, 10, "prontera"}} end)
      stub(PlayerSession, :resurrect, fn _pid, 1_000, 10 -> :ok end)

      assert {:ok, updated} =
               Interpreter.complete_cast(resurrection_game_state(), 54, 1, {:unit, 2_000})

      assert updated.stats.current_state.sp == 40
      assert updated.inventory == %{}
      assert length(updated.pending_inventory_persist) == 1
    end

    test "a successful offensive Resurrection charges SP and its Blue Gemstone" do
      stub_offensive_resurrection(:ok)

      assert {:ok, updated} =
               Interpreter.complete_cast(resurrection_game_state(), 54, 1, {:unit, 2_000})

      assert updated.stats.current_state.sp == 40
      assert updated.inventory == %{}
      assert length(updated.pending_inventory_persist) == 1
    end

    test "a failed offensive Resurrection delivery retains SP and its Blue Gemstone" do
      gs = resurrection_game_state()
      stub_offensive_resurrection({:error, :target_not_found})

      assert {:error, :target_not_found} =
               Interpreter.complete_cast(gs, 54, 1, {:unit, 2_000})

      assert gs.stats.current_state.sp == 100
      assert %{0 => %InventoryItem{nameid: 717, amount: 1}} = gs.inventory
      assert gs.pending_inventory_persist == []
    end
  end

  defp stub_offensive_resurrection(delivery_result) do
    undead = resurrection_mob()

    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), undead, :mob} end)
    stub(Combat, :resolve_target_position, fn 2_000 -> {:ok, :mob, {14, 10, "prontera"}} end)

    stub(MobState, :to_combatant, fn ^undead ->
      %{race: :undead, element: {:undead, 1}, class: :normal}
    end)

    stub(MobState, :get_stats, fn ^undead -> %{hp: 100, max_hp: 100} end)
    stub(PlayerState, :get_stats, fn _caster -> %{luk: 0, int: 0, base_level: 0} end)
    stub(Combat, :execute_magic_attack, fn _caster, 2_000, _opts -> delivery_result end)
    :rand.seed(:exsss, {100, 200, 300})
  end

  defp definition_with_act_delay(act_delay) do
    %Definition{
      id: 6,
      name: :sm_provoke,
      display_name: "Act Delay Test",
      max_level: 10,
      target_type: :target_ally,
      damage_type: :no_damage,
      element: :neutral,
      range: 9,
      sp_cost: List.duplicate(9, 10),
      cast_time: [0],
      after_cast_delay: act_delay
    }
  end

  describe "after-cast act delay" do
    test "complete_cast of a skill with a positive after_cast_delay sets act_delay_until ahead" do
      stub(Catalog, :by_id, fn 6 -> {:ok, definition_with_act_delay([500])} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      gs = game_state(100, %{6 => 1})
      now = System.monotonic_time(:millisecond)

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.act_delay_until >= now + 500
    end

    test "Monk combo effect and commitment share one modifier-resolved duration" do
      gs = game_state(100, %{272 => 1}, %{delay_rate: -50})
      stats = gs.stats
      stats = %{stats | base_stats: stats.base_stats |> Map.put(:agi, 1) |> Map.put(:dex, 1)}
      stats = %{stats | derived_stats: Map.put(stats.derived_stats, :aspd, 150)}
      gs = %{gs | stats: stats}

      definition = %Definition{
        id: 272,
        name: :sm_provoke,
        display_name: "Raging Quadruple Blow",
        max_level: 5,
        target_type: :self,
        sp_cost: [0],
        after_cast_delay: [1_000]
      }

      stub(Catalog, :by_id, fn 272 -> {:ok, definition} end)

      stub(SmProvoke, :cast, fn caster, :self, 1, resolved_definition ->
        assert resolved_definition.after_cast_delay == [500]

        {:ok,
         put_in(
           caster,
           [
             Access.key!(:stats),
             Access.key!(:modifiers),
             Access.key!(:equipment),
             :delay_rate
           ],
           0
         )}
      end)

      before = System.monotonic_time(:millisecond)
      assert {:ok, updated} = Interpreter.complete_cast(gs, 272, 1, :self)
      assert updated.act_delay_until >= before + 500
      assert updated.act_delay_until < before + 600
    end

    test "complete_cast of a skill with no after_cast_delay leaves act_delay_until at 0" do
      stub(Catalog, :by_id, fn 6 -> {:ok, definition_with_act_delay([])} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      gs = game_state(100, %{6 => 1})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.act_delay_until == 0
    end

    test "complete_cast of a skill with a zero after_cast_delay leaves act_delay_until at 0" do
      stub(Catalog, :by_id, fn 6 -> {:ok, definition_with_act_delay([0])} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      gs = game_state(100, %{6 => 1})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.act_delay_until == 0
    end

    test "reduces the after-cast act delay by the summed :delay_reduction" do
      stub(Catalog, :by_id, fn 6 -> {:ok, definition_with_act_delay([500])} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      stub(StatusStorage, :get_unit_statuses, fn :player, 1000 ->
        [%StatusEntry{state: %{delay_reduction: 50}}]
      end)

      gs = game_state(100, %{6 => 1})
      before = System.monotonic_time(:millisecond)

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)

      # 50% of 500ms = 250ms; reduced delay sits below the flat 500ms value
      assert updated.act_delay_until >= before + 250
      assert updated.act_delay_until < before + 500
    end

    test "a negative equipment :delay_rate shortens the act delay" do
      stub(Catalog, :by_id, fn 6 -> {:ok, definition_with_act_delay([500])} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      gs = game_state(100, %{6 => 1}, %{delay_rate: -20})
      before = System.monotonic_time(:millisecond)

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)

      # 500ms * 0.8 = 400ms
      assert updated.act_delay_until >= before + 400
      assert updated.act_delay_until < before + 500
    end

    test "a positive equipment :delay_rate lengthens the act delay" do
      stub(Catalog, :by_id, fn 6 -> {:ok, definition_with_act_delay([500])} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      gs = game_state(100, %{6 => 1}, %{delay_rate: 50})
      before = System.monotonic_time(:millisecond)

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)

      assert updated.act_delay_until >= before + 750
    end

    test "equipment :delay_rate scales the status-reduced delay rather than summing into it" do
      stub(Catalog, :by_id, fn 6 -> {:ok, definition_with_act_delay([500])} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      stub(StatusStorage, :get_unit_statuses, fn :player, 1000 ->
        [%StatusEntry{state: %{delay_reduction: 50}}]
      end)

      gs = game_state(100, %{6 => 1}, %{delay_rate: -50})
      before = System.monotonic_time(:millisecond)

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)

      # 500 * 0.5 * 0.5 = 125ms, not the 0ms an additive -100% would give
      assert updated.act_delay_until >= before + 125
      assert updated.act_delay_until < before + 250
    end

    test "sums :delay_reduction across multiple statuses" do
      stub(Catalog, :by_id, fn 6 -> {:ok, definition_with_act_delay([500])} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      stub(StatusStorage, :get_unit_statuses, fn :player, 1000 ->
        [
          %StatusEntry{state: %{delay_reduction: 30}},
          %StatusEntry{state: %{delay_reduction: 20}}
        ]
      end)

      gs = game_state(100, %{6 => 1})
      before = System.monotonic_time(:millisecond)

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)

      # 30 + 20 = 50% -> 250ms
      assert updated.act_delay_until >= before + 250
      assert updated.act_delay_until < before + 500
    end

    test "floors the reduced act delay at 0 when reductions exceed 100%" do
      stub(Catalog, :by_id, fn 6 -> {:ok, definition_with_act_delay([500])} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      stub(StatusStorage, :get_unit_statuses, fn :player, 1000 ->
        [%StatusEntry{state: %{delay_reduction: 150}}]
      end)

      gs = game_state(100, %{6 => 1})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)

      # floored delay leaves no future act delay
      assert updated.act_delay_until <= System.monotonic_time(:millisecond)
    end

    test "begin_cast is blocked with :act_delayed while act-delayed" do
      reject(&StatusInterpreter.apply_status/4)

      gs = %{
        game_state(100, %{29 => 1})
        | act_delay_until: System.monotonic_time(:millisecond) + 60_000
      }

      assert {:error, :act_delayed} = Interpreter.begin_cast(gs, 29, 1, :self)
    end

    test "cast is blocked with :act_delayed while act-delayed" do
      reject(&StatusInterpreter.apply_status/4)

      gs = %{
        game_state(100, %{29 => 1})
        | act_delay_until: System.monotonic_time(:millisecond) + 60_000
      }

      assert {:error, :act_delayed} = Interpreter.cast(gs, 29, 1, :self)
    end

    test "begin_cast succeeds when no act delay is pending" do
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _params -> :ok end)

      gs = %{game_state(100, %{29 => 1}) | act_delay_until: 0}

      assert {:casting, _gs, _info} = Interpreter.begin_cast(gs, 29, 1, :self)
    end
  end

  describe "ammo requirement" do
    @ammo_bit 0x008000

    defp ammo_definition(requires_ammo) do
      %Definition{
        id: 6,
        name: :sm_provoke,
        display_name: "Ammo Test",
        max_level: 10,
        target_type: :self,
        damage_type: :no_damage,
        sp_cost: List.duplicate(9, 10),
        requires_ammo: requires_ammo
      }
    end

    defp ammo_game_state(inventory) do
      Map.merge(game_state(100, %{6 => 1}), %{
        inventory: inventory,
        pending_inventory_persist: []
      })
    end

    test "requires_ammo skill with no arrow equipped returns :no_ammo without running the behavior" do
      stub(Catalog, :by_id, fn 6 -> {:ok, ammo_definition(true)} end)
      reject(&SmProvoke.cast/4)

      assert {:error, :no_ammo} = Interpreter.cast(ammo_game_state(%{}), 6, 1, :self)
    end

    test "requires_ammo skill consumes exactly one arrow and records the inventory delta" do
      stub(Catalog, :by_id, fn 6 -> {:ok, ammo_definition(true)} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      inventory = %{0 => %InventoryItem{nameid: 1750, amount: 30, equip: @ammo_bit}}

      assert {:ok, updated} = Interpreter.cast(ammo_game_state(inventory), 6, 1, :self)
      assert updated.inventory[0].amount == 29
      assert [{_before, _after, {:reduced, 0, 29}}] = updated.pending_inventory_persist
    end

    test "requires_ammo: false skill consumes no arrow and records no delta" do
      stub(Catalog, :by_id, fn 6 -> {:ok, ammo_definition(false)} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      inventory = %{0 => %InventoryItem{nameid: 1750, amount: 30, equip: @ammo_bit}}

      assert {:ok, updated} = Interpreter.cast(ammo_game_state(inventory), 6, 1, :self)
      assert updated.inventory[0].amount == 30
      assert updated.pending_inventory_persist == []
    end
  end

  describe "weapon requirement" do
    defp weapon_definition(require_weapon) do
      %Definition{
        id: 6,
        name: :sm_provoke,
        display_name: "Weapon Test",
        max_level: 10,
        target_type: :self,
        damage_type: :no_damage,
        sp_cost: List.duplicate(9, 10),
        require_weapon: require_weapon
      }
    end

    defp equipped_game_state(equipment) do
      gs = game_state(100, %{6 => 1})
      %{gs | stats: %{gs.stats | equipment: equipment}}
    end

    setup do
      stub(ItemManagement, :get_item_by_id, fn
        90_201 ->
          {:ok,
           %ItemDefinition{
             id: 90_201,
             aegis_name: "test_musical",
             name: "Test Musical",
             subtype: :musical,
             type: :weapon
           }}

        90_202 ->
          {:ok,
           %ItemDefinition{
             id: 90_202,
             aegis_name: "test_sword",
             name: "Test Sword",
             subtype: :one_handed_sword,
             type: :weapon
           }}
      end)

      :ok
    end

    test "an unrestricted skill casts without player equipment" do
      stub(Catalog, :by_id, fn 6 -> {:ok, weapon_definition([])} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      assert {:ok, _} = Interpreter.cast(game_state(100, %{6 => 1}), 6, 1, :self)
    end

    test "a listed player weapon is allowed" do
      stub(Catalog, :by_id, fn 6 -> {:ok, weapon_definition([:musical])} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      assert {:ok, _} =
               Interpreter.cast(
                 equipped_game_state(%Equipment{right_hand: 90_201}),
                 6,
                 1,
                 :self
               )
    end

    test "a missing player weapon is rejected" do
      stub(Catalog, :by_id, fn 6 -> {:ok, weapon_definition([:musical])} end)
      reject(&SmProvoke.cast/4)

      assert {:error, :wrong_weapon} =
               Interpreter.cast(equipped_game_state(%Equipment{}), 6, 1, :self)
    end

    test "ordinary preflight rejects mob casters without lifecycle adapters" do
      definition = %{weapon_definition([:musical]) | sp_cost: [:all]}
      stub(Catalog, :by_id, fn 6 -> {:ok, definition} end)

      caster =
        resurrection_mob()
        |> Map.merge(%{
          stats: %{
            current_state: %{hp: 100, sp: 100},
            progression: %{learned_skills: %{6 => 1}}
          },
          skill_cooldowns: %{},
          act_delay_until: 0
        })

      assert {:error, :unsupported_caster} = Interpreter.preflight_cast(caster, 6, 1, :self)
      refute Map.has_key?(caster.stats, :equipment)
    end

    test "a mismatched player weapon fails before cost and cooldown validation" do
      stub(Catalog, :by_id, fn 6 -> {:ok, weapon_definition([:musical])} end)
      reject(&SmProvoke.cast/4)

      gs =
        %{
          equipped_game_state(%Equipment{right_hand: 90_202})
          | skill_cooldowns: %{6 => System.monotonic_time(:millisecond) + 60_000}
        }
        |> put_in(
          [Access.key!(:stats), Access.key!(:current_state), Access.key!(:sp)],
          0
        )

      assert {:error, :wrong_weapon} = Interpreter.cast(gs, 6, 1, :self)
      assert gs.stats.current_state.sp == 0
    end
  end

  # The restricted entry SA_AUTOSPELL's proc casts through (battle.cpp:7502-7526):
  # no cast time, no catalyst, SP fixed at 2/3 of the bolt's, aftercast delay
  # applied. MG_FIREBOLT (19) costs 12 SP at level 1 and delays 1400ms.
  describe "auto_cast/4" do
    setup do
      stub(Combat, :execute_magic_attack, fn _caster, _target_id, _opts -> :ok end)
      :ok
    end

    test "charges two thirds of the bolt's SP, rounded down" do
      gs = game_state(100, %{})

      assert {:ok, updated} = Interpreter.auto_cast(gs, 19, 1, {:unit, 2001})
      assert updated.stats.current_state.sp == 92
    end

    test "the SP cost tracks the proc level, not the caster's" do
      gs = game_state(100, %{})

      assert {:ok, updated} = Interpreter.auto_cast(gs, 19, 10, {:unit, 2001})
      assert updated.stats.current_state.sp == 80
    end

    test "applies the bolt's aftercast delay" do
      gs = game_state(100, %{})
      before = System.monotonic_time(:millisecond)

      assert {:ok, updated} = Interpreter.auto_cast(gs, 19, 1, {:unit, 2001})
      assert updated.act_delay_until >= before + 1400
    end

    test "sets no cooldown of its own" do
      gs = game_state(100, %{})

      assert {:ok, updated} = Interpreter.auto_cast(gs, 19, 1, {:unit, 2001})
      assert updated.skill_cooldowns == %{}
    end

    # rAthena's `status_charge` simply fails and the whole proc is skipped: no
    # message, no delay, no cast.
    test "fizzles silently when SP is short, spending nothing and casting nothing" do
      reject(&Combat.execute_magic_attack/3)
      gs = game_state(7, %{})

      assert {:error, :insufficient_sp} = Interpreter.auto_cast(gs, 19, 1, {:unit, 2001})
    end

    test "exactly enough SP still procs" do
      gs = game_state(8, %{})

      assert {:ok, updated} = Interpreter.auto_cast(gs, 19, 1, {:unit, 2001})
      assert updated.stats.current_state.sp == 0
    end

    # The proc arms a bolt the caster learned, but rAthena re-checks nothing at
    # proc time - and neither do the act delay and cooldown that gate a real cast.
    test "runs while the caster is act-delayed and without a learned check" do
      gs = %{game_state(100, %{}) | act_delay_until: System.monotonic_time(:millisecond) + 10_000}

      assert {:ok, _} = Interpreter.auto_cast(gs, 19, 1, {:unit, 2001})
    end

    test "an unknown skill id is refused rather than cast" do
      assert {:error, :unknown_skill} =
               Interpreter.auto_cast(game_state(100, %{}), 999_999, 1, {:unit, 2001})
    end

    test "a level of zero is refused rather than read off the end of the cost table" do
      assert {:error, :invalid_level} =
               Interpreter.auto_cast(game_state(100, %{}), 19, 0, {:unit, 2001})
    end
  end

  # rAthena switches on `skill_get_casttype` and sends a ground bolt to the
  # victim's cell via `skill_castend_pos2` (battle.cpp:7508-7510).
  describe "auto_cast/4 with a ground bolt" do
    test "casts WZ_HEAVENDRIVE at the victim's cell" do
      stub(Combat, :resolve_target_position, fn 2001 -> {:ok, :mob, {14, 12, "prontera"}} end)

      test_pid = self()

      stub(Combat, :execute_magic_splash, fn _caster, center, _radius, _opts ->
        send(test_pid, {:splash_at, center})
        []
      end)

      assert {:ok, _} = Interpreter.auto_cast(game_state(100, %{}), 91, 1, {:unit, 2001})
      assert_received {:splash_at, {14, 12}}
    end

    test "fizzles when the victim's position cannot be resolved" do
      stub(Combat, :resolve_target_position, fn 2001 -> {:error, :target_not_found} end)

      assert {:error, :target_not_found} =
               Interpreter.auto_cast(game_state(100, %{}), 91, 1, {:unit, 2001})
    end
  end

  # An item-triggered cast pays with the item: it bypasses every requirement a
  # player cast earns (learned level, SP, zeny, catalysts, ammo, act delay) and
  # charges none of them, while still arming the skill's own pacing.
  describe "item_cast/4" do
    @gem_id 716

    defp item_definition(overrides \\ %{}) do
      Map.merge(
        %Definition{
          id: 6,
          name: :sm_provoke,
          display_name: "Item Cast Test",
          max_level: 10,
          target_type: :self,
          damage_type: :no_damage,
          sp_cost: List.duplicate(9, 10),
          zeny_cost: List.duplicate(100, 10),
          item_cost: [%{id: @gem_id, amount: 1}],
          requires_ammo: true,
          after_cast_delay: List.duplicate(700, 10),
          cooldown: List.duplicate(3000, 10)
        },
        overrides
      )
    end

    defp item_game_state do
      Map.merge(game_state(100, %{}), %{
        zeny: 0,
        inventory: %{0 => %InventoryItem{nameid: @gem_id, amount: 3, equip: 0}},
        pending_inventory_persist: []
      })
    end

    setup do
      stub(Catalog, :by_id, fn
        6 -> {:ok, item_definition()}
        other -> call_original(Catalog, :by_id, [other])
      end)

      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)
      :ok
    end

    test "rejects a non-player caster" do
      assert {:error, :unsupported_caster} =
               Interpreter.item_cast(struct(HomunculusState), 6, 1, :self)
    end

    test "casts a skill the player never learned" do
      assert {:ok, _updated} = Interpreter.item_cast(item_game_state(), 6, 1, :self)
    end

    test "charges no SP" do
      assert {:ok, updated} = Interpreter.item_cast(item_game_state(), 6, 1, :self)
      assert updated.stats.current_state.sp == 100
    end

    test "charges no zeny even with none to spend" do
      assert {:ok, updated} = Interpreter.item_cast(item_game_state(), 6, 1, :self)
      assert updated.zeny == 0
    end

    test "consumes no catalyst and stages no inventory delta" do
      assert {:ok, updated} = Interpreter.item_cast(item_game_state(), 6, 1, :self)
      assert %{0 => %InventoryItem{amount: 3}} = updated.inventory
      assert updated.pending_inventory_persist == []
    end

    test "casts without the catalyst in the inventory at all" do
      gs = %{item_game_state() | inventory: %{}}

      assert {:ok, _updated} = Interpreter.item_cast(gs, 6, 1, :self)
    end

    test "casts with no arrow equipped despite requires_ammo, and consumes none" do
      gs = %{item_game_state() | inventory: %{}}

      assert {:ok, updated} = Interpreter.item_cast(gs, 6, 1, :self)
      assert updated.pending_inventory_persist == []
    end

    test "casts while the player is act-delayed" do
      gs = %{item_game_state() | act_delay_until: System.monotonic_time(:millisecond) + 10_000}

      assert {:ok, _updated} = Interpreter.item_cast(gs, 6, 1, :self)
    end

    test "casts while the skill is on cooldown" do
      gs = %{
        item_game_state()
        | skill_cooldowns: %{6 => System.monotonic_time(:millisecond) + 5000}
      }

      assert {:ok, _updated} = Interpreter.item_cast(gs, 6, 1, :self)
    end

    test "arms the skill's cooldown and aftercast delay" do
      before = System.monotonic_time(:millisecond)

      assert {:ok, updated} = Interpreter.item_cast(item_game_state(), 6, 1, :self)
      assert updated.skill_cooldowns[6] >= before + 3000
      assert updated.act_delay_until >= before + 700
    end

    test "a cooldown-free skill writes no cooldown and reads no equipment" do
      stub(Catalog, :by_id, fn 6 ->
        {:ok, item_definition(%{cooldown: [], after_cast_delay: []})}
      end)

      gs = %{item_game_state() | stats: Map.delete(item_game_state().stats, :modifiers)}

      assert {:ok, updated} = Interpreter.item_cast(gs, 6, 1, :self)
      assert updated.skill_cooldowns == %{}
    end

    test "still refuses an unknown skill" do
      assert {:error, :unknown_skill} =
               Interpreter.item_cast(item_game_state(), 999_999, 1, :self)
    end

    test "still refuses a level above the skill's max" do
      assert {:error, :invalid_level} = Interpreter.item_cast(item_game_state(), 6, 11, :self)
    end

    test "still refuses a level of zero" do
      assert {:error, :invalid_level} = Interpreter.item_cast(item_game_state(), 6, 0, :self)
    end

    test "still refuses a passive skill" do
      stub(Catalog, :by_id, fn 6 -> {:ok, item_definition(%{target_type: :passive})} end)

      assert {:error, :passive_skill} = Interpreter.item_cast(item_game_state(), 6, 1, :self)
    end

    test "still honours the behavior module's own validate/4" do
      stub(Catalog, :by_id, fn 6 -> {:ok, item_definition()} end)
      stub(SmProvoke, :validate, fn _gs, _target, _level, _definition -> {:error, :nope} end)
      reject(&SmProvoke.cast/4)

      assert {:error, :nope} = Interpreter.item_cast(item_game_state(), 6, 1, :self)
    end
  end

  describe "Encore replay seam" do
    @replay_definition %Definition{
      id: 319,
      name: :cost_skill,
      display_name: "Replay Skill",
      max_level: 3,
      target_type: :self,
      sp_cost: [0, 0, 0],
      cast_time: [100, 200, 300],
      fixed_cast_time: [10, 20, 30],
      cooldown: [5_000, 6_000, 7_000]
    }

    test "all entry points reject a remembered id outside the five-skill allowlist" do
      memory = %{skill_id: 318, level: 1}
      reject(&Catalog.by_id/1)

      assert {:error, :skill_not_replayable} =
               Interpreter.encore_replay_preflight(game_state(100, %{}), memory, :self)

      assert {:error, :skill_not_replayable} =
               Interpreter.encore_replay_timing(game_state(100, %{}), memory, :self)

      assert {:error, :skill_not_replayable} =
               Interpreter.complete_encore_replay(game_state(100, %{}), memory, :self)
    end

    test "preflight accepts a remembered ensemble" do
      skill_id = EnsembleSkill.definition().id

      assert :ok =
               Interpreter.encore_replay_preflight(
                 game_state(100, %{skill_id => 1}),
                 %{skill_id: skill_id, level: 1},
                 :self
               )
    end

    test "preflight and timing use the remembered current definition and level" do
      stub(Catalog, :by_id, fn 319 -> {:ok, @replay_definition} end)
      stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, StaticCostSkill} end)
      state = game_state(100, %{319 => 2})
      memory = %{skill_id: 319, level: 2}

      assert :ok = Interpreter.encore_replay_preflight(state, memory, :self)

      assert {:ok, %{cast_time: 200, fixed_cast_time: 20}} =
               Interpreter.encore_replay_timing(state, memory, :self)
    end

    test "completion invokes one validated effect and writes only the original cooldown" do
      stub(Catalog, :by_id, fn 319 -> {:ok, @replay_definition} end)
      stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, StaticCostSkill} end)
      state = game_state(100, %{319 => 2})

      assert {:ok, updated} =
               Interpreter.complete_encore_replay(state, %{skill_id: 319, level: 2}, :self)

      assert_received {:cost_skill_sp, 100}
      assert updated.stats.current_state.sp == 100
      assert Map.keys(updated.skill_cooldowns) == [319]
    end

    test "completion revalidates the module before effect or cooldown" do
      stub(Catalog, :by_id, fn 319 -> {:ok, @replay_definition} end)
      stub(Catalog, :active_module_for, fn :cost_skill -> {:ok, CompletionValidationSkill} end)
      Process.put(:interpreter_test_allow_cast?, true)
      state = game_state(100, %{319 => 2})
      memory = %{skill_id: 319, level: 2}

      assert :ok = Interpreter.encore_replay_preflight(state, memory, :self)

      Process.put(:interpreter_test_allow_cast?, false)

      assert {:error, :requirements_changed} =
               Interpreter.complete_encore_replay(state, memory, :self)

      refute_received :completion_validation_effect
      assert state.skill_cooldowns == %{}
    end
  end
end
