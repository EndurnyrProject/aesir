defmodule Aesir.ZoneServer.Mmo.Skill.SmMagnumTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Behaviors
  alias Aesir.ZoneServer.Mmo.Skill.Behaviors.SmMagnum
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "Behaviors.module_for/1 resolves sm_magnum" do
    assert {:ok, SmMagnum} = Behaviors.module_for(:sm_magnum)
  end

  test "cast/4 splashes fire at the caster cell, knocks each hit back, and self-endows fire" do
    {:ok, definition} = Catalog.by_id(7)
    caster = %{character_id: 42, x: 10, y: 20}
    level = 3
    duration = Enum.at(definition.duration, level - 1)

    expect(Combat, :execute_splash_attack, fn ^caster, {10, 20}, 2, opts ->
      assert opts[:skill_id] == definition.id
      assert opts[:skill_level] == level
      assert opts[:skill_ratio] == 100
      assert opts[:skip_crit] == true
      [101, 102]
    end)

    expect(Combat, :knockback, 2, fn :mob, target_id, 10, 20, 2 ->
      assert target_id in [101, 102]
      {:ok, {0, 0}}
    end)

    expect(StatusInterpreter, :apply_status, fn :player, 42, :sc_watk_element, params ->
      assert params[:val1] == 3
      assert params[:caster_id] == 42
      assert params[:duration] == duration
      :ok
    end)

    assert {:ok, ^caster} = SmMagnum.cast(caster, :self, level, definition)
  end
end
