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
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Id, as: SkillUnitId
  alias Aesir.ZoneServer.Mmo.Skills.SmProvoke
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :setup_ets_tables
  setup :verify_on_exit!

  defp game_state(sp, learned) do
    %{
      character_id: 1000,
      x: 10,
      y: 10,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{sp: sp, hp: 100},
        derived_stats: %{max_sp: 200, max_hp: 100},
        progression: %{learned_skills: learned},
        equipment: %Equipment{}
      }
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

  test "unknown skill returns :unknown_skill" do
    assert {:error, :unknown_skill} =
             Interpreter.cast(game_state(100, %{29 => 1}), 999_999, 1, :self)
  end

  test "skill not learned returns :skill_not_learned" do
    assert {:error, :skill_not_learned} =
             Interpreter.cast(game_state(100, %{}), 29, 1, :self)
  end

  test "casting above learned level returns :skill_not_learned" do
    assert {:error, :skill_not_learned} =
             Interpreter.cast(game_state(100, %{29 => 1}), 29, 5, :self)
  end

  test "insufficient SP returns :insufficient_sp and does not apply the effect" do
    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :insufficient_sp} =
             Interpreter.cast(game_state(1, %{29 => 1}), 29, 1, :self)
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

  test "happy path applies the effect and deducts SP" do
    stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _params -> :ok end)

    gs = game_state(100, %{29 => 1})
    assert {:ok, updated} = Interpreter.cast(gs, 29, 1, :self)
    assert updated.stats.current_state.sp == 100 - 18
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

  describe "complete_cast/4" do
    test "deducts SP, runs the behavior, and sets the cooldown" do
      stub(Catalog, :by_id, fn 6 -> {:ok, instant_definition()} end)
      stub(SmProvoke, :cast, fn caster, :self, 1, _definition -> {:ok, caster} end)

      gs = game_state(100, %{6 => 1})

      assert {:ok, updated} = Interpreter.complete_cast(gs, 6, 1, :self)
      assert updated.stats.current_state.sp == 100 - 9
      assert Map.has_key?(updated.skill_cooldowns, 6)
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
end
