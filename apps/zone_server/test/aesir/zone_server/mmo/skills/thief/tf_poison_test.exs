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

  test "cast/4 hits with 100% ratio, poison element, +15*level Envenom ATK, no crit" do
    caster = caster()

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == definition().id
      assert opts[:skill_level] == 6
      assert opts[:skill_ratio] == 100
      assert opts[:envenom_atk] == 15 * 6
      assert opts[:element] == :poison
      assert opts[:skip_crit] == true
      assert opts[:report_hit] == true
      {:ok, %{hit?: true}}
    end)

    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
    stub(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_poison, _params -> :ok end)

    assert {:ok, ^caster} = TfPoison.cast(caster, {:unit, @target_id}, 6, definition())
  end

  @tag game_mode: :renewal
  test "applies sc_poison for 18000ms with the source chance" do
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> {:ok, %{hit?: true}} end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_poison, params ->
      assert params == [
               duration: 18_000,
               success_rate: 34,
               caster_id: 1_000,
               source_type: :player
             ]

      :ok
    end)

    assert {:ok, ^caster} = TfPoison.cast(caster, {:unit, @target_id}, 6, definition())
  end

  @tag game_mode: :pre_renewal
  test "classic applies sc_poison for 60000ms with the source chance" do
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> {:ok, %{hit?: true}} end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_poison, params ->
      assert params == [
               duration: 60_000,
               success_rate: 34,
               caster_id: 1_000,
               source_type: :player
             ]

      :ok
    end)

    assert {:ok, ^caster} = TfPoison.cast(caster, {:unit, @target_id}, 6, definition())
  end

  test "forwards the level-one poison chance to the status defense" do
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> {:ok, %{hit?: true}} end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_poison, params ->
      assert params[:success_rate] == 14
      {:error, :resisted}
    end)

    assert {:ok, ^caster} = TfPoison.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "applies sc_poison to a player target when the mob lookup misses" do
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> {:ok, %{hit?: true}} end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> false end)

    expect(StatusInterpreter, :apply_status, fn :player, @target_id, :sc_poison, _params ->
      :ok
    end)

    assert {:ok, ^caster} = TfPoison.cast(caster, {:unit, @target_id}, 10, definition())
  end

  test "does not apply sc_poison when the attack is dodged, but still returns {:ok, caster}" do
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
