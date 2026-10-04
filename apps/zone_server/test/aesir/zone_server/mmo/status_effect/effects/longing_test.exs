defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.LongingTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Longing
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule SupportBlock do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_support_block,
      no_dispel: false,
      properties: [:prevents_support_skills]
  end

  setup :setup_ets_tables
  setup :set_mimic_private

  test "Longing's movement and ASPD penalties vanish at level five" do
    for {level, penalty} <- [{1, 40}, {2, 30}, {3, 20}, {4, 10}, {5, 0}] do
      assert %{movement_speed: ^penalty, aspd_rate: aspd} =
               Longing.modifiers(%StatusEntry{val1: level}, %{})

      assert aspd == -penalty
    end
  end

  test "support-blocking statuses refuse ally casts without blocking unrelated skills" do
    Registry.register_module(SupportBlock)

    player =
      PlayerStateFixture.build(%{
        character_id: 17,
        stats: %{progression: %{learned_skills: %{28 => 1}}}
      })

    :ok = UnitRegistry.register_player(player, self())
    refute Interpreter.support_blocked?(:player, 17)
    :ok = StatusStorage.apply_status(:player, 17, :sc_test_support_block)
    assert Interpreter.support_blocked?(:player, 17)
    assert Interpreter.can_use_skill?(:player, 17, 28)
    assert {:error, :status_blocked} = SkillInterpreter.cast(player, 28, 1, {:unit, 17})
    assert {:error, :status_blocked} = SkillInterpreter.complete_cast(player, 28, 1, {:unit, 17})
  end

  test "support blocking recognizes statuses on mobs too" do
    Registry.register_module(SupportBlock)
    :ok = StatusStorage.apply_status(:mob, 19, :sc_test_support_block)
    assert Interpreter.support_blocked?(:mob, 19)

    mob = %MobState{
      instance_id: 19,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      map_name: "prontera",
      x: 100,
      y: 100,
      hp: 100,
      max_hp: 100,
      sp: 100,
      max_sp: 100,
      spawned_at: 0
    }

    assert {:error, :status_blocked} =
             Executor.execute(mob, %{skill_id: 28, level: 1, target: :self})
  end
end
