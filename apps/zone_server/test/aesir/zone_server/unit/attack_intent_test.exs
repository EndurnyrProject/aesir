defmodule Aesir.ZoneServer.Unit.AttackIntentTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Unit.AttackIntent
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  test "dispatches one typed intent to a player owner" do
    UnitRegistry.register_unit(:player, 1_001, PlayerSession, %{}, self())

    assert :ok = AttackIntent.start({:player, 1_001}, {:mob, 2_001})
    assert_receive {:attack_intent, {:mob, 2_001}}
    refute_receive {:attack_intent, _}
  end

  test "dispatches one typed intent to a mob owner" do
    UnitRegistry.register_unit(:mob, 2_001, MobSession, %{}, self())

    assert :ok = AttackIntent.start({:mob, 2_001}, {:player, 1_001})
    assert_receive {:attack_intent, {:player, 1_001}}
    refute_receive {:attack_intent, _}
  end

  test "drops an intent when the holder disappeared" do
    assert :ok = AttackIntent.start({:player, 1_001}, {:mob, 2_001})
    refute_receive {:attack_intent, _}
  end

  test "rejects invalid and unsupported typed references" do
    assert {:error, :invalid_ref} = AttackIntent.start({:player, 0}, {:mob, 2_001})
    assert {:error, :unsupported_holder} = AttackIntent.start({:homunculus, 3_001}, {:mob, 2_001})
  end

  test "player routing uses one existing single-attack action" do
    state = %{game_state: %{character_id: 1_001}}

    expect(CombatActionHandler, :handle_attack_request, fn ^state, 2_001, 0 ->
      {:noreply, state}
    end)

    assert {:noreply, ^state} = PlayerSession.handle_info({:attack_intent, {:mob, 2_001}}, state)
  end

  test "mob routing uses the existing typed damage-reaction boundary" do
    state = struct(MobState, instance_id: 2_001, is_dead: false)

    assert {:noreply, reacted} =
             MobSession.handle_info({:attack_intent, {:player, 1_001}}, state)

    assert reacted.target_ref == {:player, 1_001}
    assert reacted.ai_state == :combat
  end

  test "dead mob rejects an attack intent without changing state" do
    state = struct(MobState, instance_id: 2_001, is_dead: true)

    assert {:noreply, ^state} =
             MobSession.handle_info({:attack_intent, {:player, 1_001}}, state)
  end
end
