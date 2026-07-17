defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.DispelTest do
  @moduledoc """
  Coverage for the mob dispel archetype: the `50 + 10*lv`% success roll lives
  here (the `Dispel` primitive takes no level), and a successful roll delegates
  the whole removal to `StatusEffect.Dispel.dispel/1`.
  """

  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.Dispel, as: DispelArchetype
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Unit.Mob.MobState

  setup :set_mimic_private
  setup :verify_on_exit!

  @caster_id 5001
  @target_id 42
  @map "prontera"

  defp build_caster do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "TEST_CASTER",
      name: "Test Caster",
      level: 25,
      hp: 1000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(@caster_id, mob_data, spawn_ref, @map, 100, 100)
  end

  defp params, do: %{skill_id: 289, skill: "SA_DISPELL"}

  describe "apply/5" do
    test "a successful roll dispels the resolved player target" do
      test_pid = self()

      expect(Dispel, :dispel, fn target ->
        send(test_pid, {:dispelled, target})
        :ok
      end)

      assert :ok =
               DispelArchetype.apply(
                 build_caster(),
                 {:unit, :player, @target_id},
                 params(),
                 1,
                 rng: fn 100 -> 60 end
               )

      assert_received {:dispelled, {:player, @target_id}}
    end

    test "a failed roll is a clean no-op" do
      reject(&Dispel.dispel/1)

      assert :ok =
               DispelArchetype.apply(
                 build_caster(),
                 {:unit, :player, @target_id},
                 params(),
                 1,
                 rng: fn 100 -> 61 end
               )
    end

    @thresholds [{1, 60}, {2, 70}, {3, 80}, {4, 90}, {5, 100}]

    test "a roll on the 50 + 10*lv threshold still succeeds at every level" do
      test_pid = self()

      stub(Dispel, :dispel, fn target ->
        send(test_pid, {:dispelled, target})
        :ok
      end)

      for {level, threshold} <- @thresholds do
        assert :ok =
                 DispelArchetype.apply(
                   build_caster(),
                   {:unit, :player, @target_id},
                   params(),
                   level,
                   rng: fn 100 -> threshold end
                 )

        assert_received {:dispelled, {:player, @target_id}}
      end
    end

    test "a roll one over the threshold fails at every level" do
      reject(&Dispel.dispel/1)

      for {level, threshold} <- @thresholds, threshold < 100 do
        assert :ok =
                 DispelArchetype.apply(
                   build_caster(),
                   {:unit, :player, @target_id},
                   params(),
                   level,
                   rng: fn 100 -> threshold + 1 end
                 )
      end
    end

    test "a non-player target is rejected without a roll" do
      reject(&Dispel.dispel/1)

      assert {:error, :invalid_target} =
               DispelArchetype.apply(build_caster(), {:unit, :mob, 7}, params(), 5)

      assert {:error, :invalid_target} =
               DispelArchetype.apply(build_caster(), {:ground, 10, 10, :around}, params(), 5)
    end
  end

  describe "apply/4" do
    test "defaults to the real rng and dispels at level 5 (a 100% roll)" do
      test_pid = self()

      expect(Dispel, :dispel, fn target ->
        send(test_pid, {:dispelled, target})
        :ok
      end)

      assert :ok =
               DispelArchetype.apply(build_caster(), {:unit, :player, @target_id}, params(), 5)

      assert_received {:dispelled, {:player, @target_id}}
    end
  end
end
