defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfThrowstoneTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfThrowstone
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @target_id 2000

  defp caster, do: %{character_id: 1000}

  defp definition do
    {:ok, definition} = Catalog.by_id(152)
    definition
  end

  test "Catalog.by_id/1 resolves TF_THROWSTONE" do
    assert definition().name == :tf_throwstone
    assert definition().max_level == 1
    assert definition().target_type == :target_enemy
    assert definition().damage_type == :damage
    assert definition().damage_kind == :misc
    assert definition().element == :neutral
    assert definition().range == 7
    assert definition().sp_cost == [2]
  end

  test "cast/4 deals a fixed 50 misc damage in neutral element" do
    caster = caster()

    expect(Combat, :execute_misc_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == definition().id
      assert opts[:skill_level] == 1
      assert opts[:base_damage] == 50
      assert opts[:element] == :neutral
      :ok
    end)

    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
    reject(&StatusInterpreter.apply_status/4)
    :rand.seed(:exsss, {1, 1, 1})

    assert {:ok, ^caster} = TfThrowstone.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "a monster caster flings for 30 and can only stun" do
    caster = %{instance_id: 77}
    :rand.seed(:exsss, {9, 9, 9})
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(Combat, :execute_misc_attack, fn ^caster, @target_id, opts ->
      assert opts[:base_damage] == 30
      :ok
    end)

    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} = TfThrowstone.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "the definition consumes one Stone per cast" do
    assert definition().item_cost == [%{id: 7049, amount: 1}]
  end

  test "renewal has a 100 ms after-cast delay and classic none" do
    assert TfThrowstone.definition(:renewal).after_cast_delay == [100]
    assert TfThrowstone.definition(:pre_renewal).after_cast_delay == [0]
  end

  @tag game_mode: :renewal
  test "applies sc_stun for 4500ms when the 3% stun roll succeeds, without rolling blind" do
    # Seed {1,1,185} yields :rand.uniform(100) == 1, at or below the 3% stun chance.
    :rand.seed(:exsss, {1, 1, 185})
    caster = caster()

    stub(Combat, :execute_misc_attack, fn ^caster, @target_id, _opts -> :ok end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stun, params ->
      assert params[:duration] == 4_500
      :ok
    end)

    assert {:ok, ^caster} = TfThrowstone.cast(caster, {:unit, @target_id}, 1, definition())
  end

  @tag game_mode: :pre_renewal
  test "classic applies sc_stun for 5000ms when the 3% stun roll succeeds, without rolling blind" do
    # Seed {1,1,185} yields :rand.uniform(100) == 1, at or below the 3% stun chance.
    :rand.seed(:exsss, {1, 1, 185})
    caster = caster()

    stub(Combat, :execute_misc_attack, fn ^caster, @target_id, _opts -> :ok end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stun, params ->
      assert params[:duration] == 5_000
      :ok
    end)

    assert {:ok, ^caster} = TfThrowstone.cast(caster, {:unit, @target_id}, 1, definition())
  end

  @tag game_mode: :renewal
  test "applies sc_blind for 20000ms only when the stun roll fails and the blind roll succeeds" do
    # Seed {1,1,20} yields rolls 76 (stun fails, > 3%) then 3 (blind succeeds, <= 3%).
    :rand.seed(:exsss, {1, 1, 20})
    caster = caster()

    stub(Combat, :execute_misc_attack, fn ^caster, @target_id, _opts -> :ok end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_blind, params ->
      assert params[:duration] == 20_000
      :ok
    end)

    assert {:ok, ^caster} = TfThrowstone.cast(caster, {:unit, @target_id}, 1, definition())
  end

  @tag game_mode: :pre_renewal
  test "classic applies sc_blind for 30000ms only when the stun roll fails and the blind roll succeeds" do
    # Seed {1,1,20} yields rolls 76 (stun fails, > 3%) then 3 (blind succeeds, <= 3%).
    :rand.seed(:exsss, {1, 1, 20})
    caster = caster()

    stub(Combat, :execute_misc_attack, fn ^caster, @target_id, _opts -> :ok end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_blind, params ->
      assert params[:duration] == 30_000
      :ok
    end)

    assert {:ok, ^caster} = TfThrowstone.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "applies neither status when both rolls fail" do
    # Seed {1,1,1} yields rolls 8 then 50, both above the 3% chance.
    :rand.seed(:exsss, {1, 1, 1})
    caster = caster()

    stub(Combat, :execute_misc_attack, fn ^caster, @target_id, _opts -> :ok end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} = TfThrowstone.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "propagates an attack error without rolling status" do
    caster = caster()

    stub(Combat, :execute_misc_attack, fn ^caster, @target_id, _opts ->
      {:error, :target_out_of_range}
    end)

    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :target_out_of_range} =
             TfThrowstone.cast(caster, {:unit, @target_id}, 1, definition())
  end
end
