defmodule Aesir.ZoneServer.Mmo.Skill.Behaviors.SmStormgustTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Behaviors
  alias Aesir.ZoneServer.Mmo.Skill.Behaviors.SmStormgust
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillUnit
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  defp caster, do: %PlayerState{character_id: 1000, map_name: "prontera", x: 100, y: 100}

  defp definition do
    {:ok, definition} = Catalog.by_name(:wz_stormgust)
    definition
  end

  test "Behaviors.module_for/1 resolves wz_stormgust" do
    assert {:ok, SmStormgust} = Behaviors.module_for(:wz_stormgust)
  end

  test "cast/4 places the ground skill-unit and returns {:ok, caster}" do
    caster = caster()

    expect(SkillUnit, :place, fn ^caster, :wz_stormgust, 7, {150, 152} ->
      {:ok, :group}
    end)

    assert {:ok, ^caster} = SmStormgust.cast(caster, {:ground, 150, 152}, 7, definition())
  end

  test "cast/4 propagates a placement error" do
    caster = caster()

    stub(SkillUnit, :place, fn _c, _name, _level, _cell -> {:error, :no_skill_unit_behaviour} end)

    assert {:error, :no_skill_unit_behaviour} =
             SmStormgust.cast(caster, {:ground, 150, 152}, 7, definition())
  end
end
