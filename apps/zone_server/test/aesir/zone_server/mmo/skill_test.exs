defmodule Aesir.ZoneServer.Mmo.SkillTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Passive
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defmodule ActiveSkill do
    use Aesir.ZoneServer.Mmo.Skill,
      id: 90_010,
      name: :test_active,
      display_name: "Test Active",
      max_level: 5,
      target_type: :target_enemy

    @behaviour Active

    @impl Active
    def cast(caster, _target, _level, _definition), do: {:ok, caster}
  end

  defmodule PassiveSkill do
    use Aesir.ZoneServer.Mmo.Skill,
      id: 90_011,
      name: :test_passive,
      display_name: "Test Passive",
      max_level: 1,
      target_type: :passive

    @behaviour Passive

    @impl Passive
    def atk_bonus(level, _ctx), do: level * 3
  end

  defmodule GroundSkill do
    use Aesir.ZoneServer.Mmo.Skill,
      id: 90_012,
      name: :test_ground,
      display_name: "Test Ground",
      max_level: 3,
      target_type: :ground,
      element: :water,
      knockback: 2,
      splash_radius: 2,
      hit_interval: 500,
      unit_duration: [1_000, 2_000, 3_000]

    @behaviour Ground

    @impl Ground
    def on_place(_group), do: {:ok, %{cells: [], state: %{}, interval: 500, duration: 1_000}}

    @impl Ground
    def on_interval(group, _now), do: {:ok, group}
  end

  describe "definition exposure" do
    test "definition/0 and skill_name/0 reflect the use opts, including combat fields" do
      definition = GroundSkill.definition()

      assert GroundSkill.skill_name() == :test_ground
      assert definition.element == :water
      assert definition.knockback == 2
      assert definition.splash_radius == 2
      assert definition.hit_interval == 500
      assert definition.unit_duration == [1_000, 2_000, 3_000]
    end

    test "combat fields default sanely when omitted" do
      definition = ActiveSkill.definition()

      assert definition.element == :neutral
      assert definition.knockback == 0
      assert definition.hit_count == 1
    end
  end

  describe "capability detection" do
    test "an active-only skill reports [:active]" do
      assert ActiveSkill.__skill_capabilities__() == [:active]
    end

    test "a passive-only skill reports [:passive]" do
      assert PassiveSkill.__skill_capabilities__() == [:passive]
    end

    test "a ground skill reports both :active and :ground" do
      assert GroundSkill.__skill_capabilities__() == [:active, :ground]
    end
  end

  describe "auto-derived ground cast" do
    test "cast/4 places the skill-unit at the target cell" do
      caster = %PlayerState{character_id: 7}
      test_pid = self()

      stub(Unit, :place, fn ^caster, :test_ground, 2, {12, 34} ->
        send(test_pid, :placed)
        {:ok, :group}
      end)

      assert {:ok, ^caster} =
               GroundSkill.cast(caster, {:ground, 12, 34}, 2, GroundSkill.definition())

      assert_received :placed
    end
  end
end
