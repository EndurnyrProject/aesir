defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfSprinklesandTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfSprinklesand
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @target_id 2000

  defp caster, do: %{character_id: 1000}

  defp definition do
    {:ok, definition} = Catalog.by_id(149)
    definition
  end

  test "cast/4 hits with a 130% ratio, earth element, no crit" do
    caster = caster()

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == definition().id
      assert opts[:skill_level] == 1
      assert opts[:skill_ratio] == 130
      assert opts[:element] == :earth
      assert opts[:skip_crit] == true
      assert opts[:report_hit] == true
      {:ok, %{hit?: true}}
    end)

    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
    stub(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_blind, _params -> :ok end)

    assert {:ok, ^caster} = TfSprinklesand.cast(caster, {:unit, @target_id}, 1, definition())
  end

  @tag game_mode: :renewal
  test "applies sc_blind for 18000ms with the 20% source chance" do
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> {:ok, %{hit?: true}} end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_blind, params ->
      assert params[:duration] == 18_000
      assert params[:success_rate] == 20
      :ok
    end)

    assert {:ok, ^caster} = TfSprinklesand.cast(caster, {:unit, @target_id}, 1, definition())
  end

  @tag game_mode: :pre_renewal
  test "classic applies sc_blind for 30000ms with the 20% source chance" do
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> {:ok, %{hit?: true}} end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_blind, params ->
      assert params[:duration] == 30_000
      assert params[:success_rate] == 20
      :ok
    end)

    assert {:ok, ^caster} = TfSprinklesand.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "forwards the 20 percent blind chance to the status defense" do
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> {:ok, %{hit?: true}} end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_blind, params ->
      assert params[:success_rate] == 20
      {:error, :resisted}
    end)

    assert {:ok, ^caster} = TfSprinklesand.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "does not apply sc_blind when the attack is dodged, but still returns {:ok, caster}" do
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> {:ok, %{hit?: false}} end)

    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} = TfSprinklesand.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "propagates an attack error without rolling blind" do
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
      {:error, :target_out_of_range}
    end)

    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :target_out_of_range} =
             TfSprinklesand.cast(caster, {:unit, @target_id}, 1, definition())
  end
end
