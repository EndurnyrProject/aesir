defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfPoisonTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfPoison
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @target_id 2000

  defp caster, do: %{character_id: 1000}

  defp definition do
    {:ok, definition} = Catalog.by_id(52)
    definition
  end

  test "Catalog.by_id/1 resolves TF_POISON" do
    assert definition().name == :tf_poison
    assert definition().target_type == :target_enemy
    assert definition().damage_type == :damage
    assert definition().element == :poison
    assert definition().range == -1
    assert definition().sp_cost == List.duplicate(12, 10)
  end

  test "cast/4 hits with 100% ratio, poison element, +15*level bonus_atk, no crit" do
    caster = caster()

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == definition().id
      assert opts[:skill_level] == 6
      assert opts[:skill_ratio] == 100
      assert opts[:bonus_atk] == 15 * 6
      assert opts[:element] == :poison
      assert opts[:skip_crit] == true
      assert opts[:report_hit] == true
      {:ok, %{hit?: true}}
    end)

    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
    stub(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_poison, _params -> :ok end)

    assert {:ok, ^caster} = TfPoison.cast(caster, {:unit, @target_id}, 6, definition())
  end

  test "applies sc_poison for 18000ms when the roll succeeds" do
    # Seed {1,2,3} yields :rand.uniform(100) == 27, at or below 4*6+10 = 34.
    :rand.seed(:exsss, {1, 2, 3})
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> {:ok, %{hit?: true}} end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_poison, params ->
      assert params[:duration] == 18_000
      :ok
    end)

    assert {:ok, ^caster} = TfPoison.cast(caster, {:unit, @target_id}, 6, definition())
  end

  test "does not apply sc_poison when the roll fails" do
    # Seed {6,7,8} yields :rand.uniform(100) == 87, above 4*1+10 = 14.
    :rand.seed(:exsss, {6, 7, 8})
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> {:ok, %{hit?: true}} end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} = TfPoison.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "applies sc_poison to a player target when the mob lookup misses" do
    # Seed {1,2,3} yields :rand.uniform(100) == 27, at or below 4*10+10 = 50.
    :rand.seed(:exsss, {1, 2, 3})
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> {:ok, %{hit?: true}} end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> false end)

    expect(StatusInterpreter, :apply_status, fn :player, @target_id, :sc_poison, _params ->
      :ok
    end)

    assert {:ok, ^caster} = TfPoison.cast(caster, {:unit, @target_id}, 10, definition())
  end

  test "does not apply sc_poison when the attack is dodged, but still returns {:ok, caster}" do
    # Seed {1,2,3} yields :rand.uniform(100) == 27, which would pass the roll
    # if it ran; the miss must skip the roll entirely.
    :rand.seed(:exsss, {1, 2, 3})
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> {:ok, %{hit?: false}} end)

    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} = TfPoison.cast(caster, {:unit, @target_id}, 10, definition())
  end

  test "propagates an attack error without rolling poison" do
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
      {:error, :target_out_of_range}
    end)

    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :target_out_of_range} =
             TfPoison.cast(caster, {:unit, @target_id}, 6, definition())
  end
end
