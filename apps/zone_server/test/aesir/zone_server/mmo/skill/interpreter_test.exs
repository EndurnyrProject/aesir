defmodule Aesir.ZoneServer.Mmo.Skill.InterpreterTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.SmProvoke
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.SpatialIndex

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
        progression: %{learned_skills: learned}
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
    stub(SpatialIndex, :get_unit_position, fn :player, 9999 -> {:ok, {20, 20, "prontera"}} end)

    gs = game_state(100, %{6 => 1})
    assert {:error, :out_of_range} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
  end

  test "targeted skill cast within definition.range proceeds to behavior" do
    stub(Catalog, :by_id, fn 6 -> {:ok, enemy_definition(5)} end)
    stub(SpatialIndex, :get_unit_position, fn :player, 9999 -> {:ok, {14, 10, "prontera"}} end)
    stub(StatusInterpreter, :apply_status, fn _type, _id, _status, _params -> :ok end)

    gs = game_state(100, %{6 => 1})
    assert {:ok, _} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
  end

  test ":self skills bypass the range check" do
    stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _params -> :ok end)

    gs = game_state(100, %{29 => 1})
    assert {:ok, _} = Interpreter.cast(gs, 29, 1, :self)
  end

  defp ally_definition(range) do
    %Definition{
      id: 6,
      name: :sm_provoke,
      display_name: "Ally Test",
      max_level: 10,
      target_type: :target_ally,
      damage_type: :no_damage,
      range: range,
      sp_cost: List.duplicate(9, 10)
    }
  end

  test "ally skill cast on another unit proceeds to behavior" do
    stub(Catalog, :by_id, fn 6 -> {:ok, ally_definition(9)} end)
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

  test "ground cast succeeds for a target_type: :ground definition" do
    stub(Catalog, :by_id, fn 6 -> {:ok, ground_definition(9)} end)
    stub(MapCache, :get, fn "prontera" -> {:ok, %MapData{}} end)
    stub(MapData, :walkable?, fn _map, 12, 12 -> true end)
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
    stub(Catalog, :by_id, fn 6 -> {:ok, ground_definition(9)} end)
    stub(MapCache, :get, fn "prontera" -> {:ok, %MapData{}} end)
    stub(MapData, :walkable?, fn _map, 12, 12 -> false end)

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
      stub(SpatialIndex, :get_unit_position, fn :player, 9999 -> {:ok, {20, 20, "prontera"}} end)

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
end
