defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmMagnumTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmMagnum
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers

  setup :verify_on_exit!

  test "Catalog.active_module_for/1 resolves sm_magnum" do
    assert {:ok, SmMagnum} = Catalog.active_module_for(:sm_magnum)
  end

  test "cast/4 resolves caster-centered mob-native blow before self-endowing fire" do
    {:ok, definition} = Catalog.by_id(7)

    caster = %PlayerState{
      character_id: 42,
      x: 10,
      y: 20,
      stats: %Stats{
        modifiers: %Modifiers{equipment: %{{:add_skill_blow, definition.id} => 3}}
      }
    }

    level = 3
    duration = Enum.at(definition.duration, level - 1)

    expect(Combat, :execute_splash_attack, fn ^caster, {10, 20}, 2, opts ->
      assert caster.stats.modifiers.equipment[{:add_skill_blow, definition.id}] == 3
      assert opts[:skill_id] == definition.id
      assert opts[:skill_level] == level
      assert opts[:skill_ratio] == 100
      assert opts[:skip_crit] == true
      assert opts[:base_distance] == 2
      assert opts[:origin] == {10, 20}
      assert opts[:native_target_types] == [:mob]
      send(self(), :combined_blow_requested)
      [101, 102]
    end)

    reject(&Combat.knockback/5)

    expect(StatusInterpreter, :apply_status, fn :player, 42, :sc_watk_element, params ->
      assert_received :combined_blow_requested
      assert params[:val1] == 3
      assert params[:caster_id] == 42
      assert params[:duration] == duration
      :ok
    end)

    assert {:ok, ^caster} = SmMagnum.cast(caster, :self, level, definition)
  end
end
