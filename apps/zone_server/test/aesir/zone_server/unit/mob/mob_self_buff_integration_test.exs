defmodule Aesir.ZoneServer.Unit.Mob.MobSelfBuffIntegrationTest do
  @moduledoc """
  End-to-end lifecycle for a mob self-buff through the live MobSkill path:
  `Executor.execute/2` resolves an `NPC_AGIUP` row's self target, dispatches to
  the real `SelfBuff` archetype, which applies `:sc_increaseagi` to the mob via
  the real status interpreter/storage. Proves Phase 2b Task 1 (status fold in
  `to_combatant/1`) and Task 4 (SelfBuff archetype) compose: the buff lands, the
  buffed AGI shows up in the combatant, and removing the status reverts it.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @base_agi 30
  @level 3

  defp build_mob_state do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1000,
      sp: 0,
      stats: %{str: 40, agi: @base_agi, vit: 50, int: 20, dex: 35, luk: 15},
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
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
  end

  defp self_buff_row do
    %{
      skill: "NPC_AGIUP",
      skill_id: 391,
      level: @level,
      target: :self,
      condition: %{type: :always}
    }
  end

  test "NPC_AGIUP self-buffs the mob, folds into to_combatant, and reverts on removal" do
    state = build_mob_state()
    UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

    assert MobState.to_combatant(state).base_stats.agi == @base_agi

    assert :ok = Executor.execute(state, self_buff_row())

    assert StatusStorage.has_status?(:mob, state.instance_id, :sc_increaseagi)
    assert MobState.to_combatant(state).base_stats.agi == @base_agi + @level

    :ok = StatusInterpreter.remove_status(:mob, state.instance_id, :sc_increaseagi)

    refute StatusStorage.has_status?(:mob, state.instance_id, :sc_increaseagi)
    assert MobState.to_combatant(state).base_stats.agi == @base_agi
  end
end
