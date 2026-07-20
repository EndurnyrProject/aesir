defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.ElementalNukeTest do
  @moduledoc """
  Integration coverage for the nuke path through the REAL
  `Combat.execute_magic_damage/4` (only the unit lookups, sessions and
  broadcast are mocked): a ranged caster whose target sits beyond melee reach
  but within `skill_range` must land the hit — the range gate uses the skill's
  reach, not the mob's melee `attack_range`.
  """

  use ExUnit.Case, async: true
  use Mimic

  # The real combat resolve tries the mob registry before the player one, so a
  # player target legitimately logs a "Mob <id> not found in registry" warning.
  @moduletag :capture_log

  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.ElementalNuke
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 5001
  @target_id 42
  @map "prontera"
  @skill_id 186

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

  defp build_target_state(x, y) do
    stats = %Stats{
      current_state: %{hp: 100},
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 1, def: 1, hit: 1, flee: 1, perfect_dodge: 1, matk: 100},
      derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
      progression: %PlayerProgression{base_level: 1, job_level: 1, learned_skills: %{}},
      equipment: %Equipment{}
    }

    %PlayerState{
      character_id: @target_id,
      account_id: @target_id,
      x: x,
      y: y,
      map_name: @map,
      action_state: :idle,
      stats: stats
    }
  end

  defp stub_player_target(x, y) do
    target_player = spawn(fn -> Process.sleep(:infinity) end)

    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:error, :not_found} end)
    stub(UnitRegistry, :get_player_pid, fn @target_id -> {:ok, target_player} end)

    stub(PlayerSession, :get_current_stats, fn ^target_player ->
      build_target_state(x, y).stats
    end)

    stub(PlayerSession, :get_state, fn ^target_player ->
      %{game_state: build_target_state(x, y)}
    end)

    stub(StatusInterpreter, :absorb_damage, fn :player, @target_id, damage, _hit_info ->
      damage
    end)

    target_player
  end

  test "lands the hit on a target beyond melee reach but within skill range" do
    caster = build_caster()
    # Distance 5: outside attack_range 1, inside skill_range 10.
    target_player = stub_player_target(105, 100)
    test_pid = self()

    stub(Broadcast, :to_in_range, fn @map, 105, 100, _range, packet ->
      send(test_pid, {:packet, packet})
      :ok
    end)

    stub(PlayerSession, :apply_damage, fn ^target_player, damage, @caster_id ->
      send(test_pid, {:damage, damage})
      :ok
    end)

    assert :ok =
             ElementalNuke.apply(
               caster,
               {:unit, :player, @target_id},
               %{skill_id: @skill_id, skill: "NPC_FIREATTACK", element: :fire},
               3
             )

    # matk 60 * level 3, fire vs neutral is a 1.0 modifier.
    assert_received {:damage, 180}
    assert_received {:packet, %SkillDamage{skill_id: @skill_id, level: 3, damage: 180}}
  end

  test "still aborts cleanly for a target beyond skill range" do
    caster = build_caster()
    stub_player_target(115, 100)

    assert {:error, :target_out_of_range} =
             ElementalNuke.apply(
               caster,
               {:unit, :player, @target_id},
               %{skill_id: @skill_id, skill: "NPC_FIREATTACK", element: :fire},
               3
             )
  end
end
