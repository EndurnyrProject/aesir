defmodule Aesir.ZoneServer.Mmo.Skill.InterpreterTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :verify_on_exit!

  defp game_state(sp, learned) do
    %{
      character_id: 1000,
      x: 10,
      y: 10,
      skill_cooldowns: %{},
      stats: %{
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

  test "targeting another unit returns :invalid_target" do
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
    assert {:error, :no_behavior} = Interpreter.cast(gs, 6, 1, {:unit, 9999})
  end

  test ":self skills bypass the range check" do
    stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _params -> :ok end)

    gs = game_state(100, %{29 => 1})
    assert {:ok, _} = Interpreter.cast(gs, 29, 1, :self)
  end
end
