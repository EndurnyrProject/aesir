defmodule Aesir.ZoneServer.Integration.MonkStatusLifecycleIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.ParamChange
  alias Aesir.Net.Respawn
  alias Aesir.Net.StatusChange
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Phoenix.PubSub

  test "Fury and Mental Strength expiry restores cached state and removes their displays" do
    player = start_player_session(id: 9_711, name: "Expiring Monk", agi: 40, luk: 30)
    baseline = get_player_state(player.pid)

    apply_monk_statuses(player)
    assert_status_effects_applied(player, baseline)
    flush_packets()

    expire_monk_statuses(player.character.id)
    StatusTickManager.force_tick()

    assert eventually(fn -> status_effects_reverted?(player, baseline) end)
    assert_single_cached_state_update(baseline)
    assert_status_displays_removed(player.character.id)
  end

  test "dispelling Fury and Mental Strength restores cached state and removes their displays" do
    player = start_player_session(id: 9_712, name: "Dispelled Monk", agi: 40, luk: 30)
    baseline = get_player_state(player.pid)

    apply_monk_statuses(player)
    assert_status_effects_applied(player, baseline)
    flush_packets()

    assert :ok = Dispel.dispel({:player, player.character.id})

    assert eventually(fn -> status_effects_reverted?(player, baseline) end)
    assert_single_cached_state_update(baseline)
    assert_status_displays_removed(player.character.id)
  end

  test "death removes Fury and Mental Strength canonically before a baseline respawn" do
    player = start_player_session(id: 9_713, name: "Fallen Monk", agi: 40, luk: 30)
    baseline = get_player_state(player.pid)
    :ok = PubSub.subscribe(Aesir.PubSub, "player:#{player.character.id}")

    apply_monk_statuses(player)
    assert_status_effects_applied(player, baseline)
    flush_packets()

    PlayerSession.apply_damage(player.pid, baseline.stats.current_state.hp, 1)

    assert eventually(fn ->
             state = get_player_state(player.pid)
             state.action_state == :dead and status_effects_reverted?(player, baseline)
           end)

    assert_status_displays_removed(player.character.id)
    refute_receive :recalculate_stats, 100

    simulate_incoming_message(player.pid, %Respawn{type: 0})

    assert eventually(fn ->
             state = get_player_state(player.pid)
             state.action_state == :idle and status_effects_reverted?(player, baseline)
           end)

    refute_receive :recalculate_stats, 100
  end

  defp apply_monk_statuses(player) do
    char_id = player.character.id

    assert :ok =
             PlayerSession.apply_status(player.pid, :sc_explosionspirits,
               caster_id: char_id,
               val1: 5,
               duration: 60_000
             )

    assert :ok =
             PlayerSession.apply_status(player.pid, :sc_steelbody,
               caster_id: char_id,
               duration: 60_000
             )
  end

  defp assert_status_effects_applied(player, baseline) do
    state = get_player_state(player.pid)
    char_id = player.character.id

    assert state.stats.combat_stats.critical > baseline.stats.combat_stats.critical
    assert state.stats.derived_stats.aspd != baseline.stats.derived_stats.aspd
    assert state.walk_speed == 200
    refute StatusInterpreter.can_use_skill?(:player, char_id)
  end

  defp expire_monk_statuses(char_id) do
    Enum.each([:sc_explosionspirits, :sc_steelbody], fn status_id ->
      :ok =
        StatusStorage.update_status(:player, char_id, status_id, fn status ->
          %{status | expires_at: System.monotonic_time(:millisecond) - 1}
        end)
    end)
  end

  defp status_effects_reverted?(player, baseline) do
    state = get_player_state(player.pid)
    char_id = player.character.id

    state.stats.combat_stats.critical == baseline.stats.combat_stats.critical and
      state.stats.derived_stats.aspd == baseline.stats.derived_stats.aspd and
      state.walk_speed == baseline.walk_speed and
      StatusInterpreter.can_use_skill?(:player, char_id) and
      not StatusStorage.has_status?(:player, char_id, :sc_explosionspirits) and
      not StatusStorage.has_status?(:player, char_id, :sc_steelbody)
  end

  defp assert_status_displays_removed(char_id) do
    assert_receive {:packet_sent, %StatusChange{unit_id: ^char_id, on: false}, _}, 1_000
    assert_receive {:packet_sent, %StatusChange{unit_id: ^char_id, on: false}, _}, 1_000
  end

  defp assert_single_cached_state_update(baseline) do
    expected = [
      {StatusParams.critical(), baseline.stats.combat_stats.critical},
      {StatusParams.aspd(), baseline.stats.derived_stats.aspd},
      {StatusParams.speed(), baseline.walk_speed}
    ]

    Enum.each(expected, fn {var_id, value} ->
      assert_receive {:packet_sent, %ParamChange{var_id: ^var_id, value: ^value}, _}, 1_000
      refute_receive {:packet_sent, %ParamChange{var_id: ^var_id}, _}
    end)
  end
end
