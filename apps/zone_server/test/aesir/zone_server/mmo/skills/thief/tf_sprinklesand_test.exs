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

  test "Catalog.by_id/1 resolves TF_SPRINKLESAND" do
    assert definition().name == :tf_sprinklesand
    assert definition().max_level == 1
    assert definition().target_type == :target_enemy
    assert definition().damage_type == :damage
    assert definition().element == :earth
    assert definition().range == 1
    assert definition().sp_cost == [9]
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

  test "applies sc_blind for 18000ms when the 20% roll succeeds" do
    # Seed {1,1,1} yields :rand.uniform(100) == 8, at or below the 20% chance.
    :rand.seed(:exsss, {1, 1, 1})
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> {:ok, %{hit?: true}} end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_blind, params ->
      assert params[:duration] == 18_000
      :ok
    end)

    assert {:ok, ^caster} = TfSprinklesand.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "does not apply sc_blind when the roll fails" do
    # Seed {6,7,8} yields :rand.uniform(100) == 87, above the 20% chance.
    :rand.seed(:exsss, {6, 7, 8})
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> {:ok, %{hit?: true}} end)
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} = TfSprinklesand.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "does not apply sc_blind when the attack is dodged, but still returns {:ok, caster}" do
    # Seed {1,1,1} yields :rand.uniform(100) == 8, which would pass the 20%
    # roll if it ran; the miss must skip the roll entirely.
    :rand.seed(:exsss, {1, 1, 1})
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
