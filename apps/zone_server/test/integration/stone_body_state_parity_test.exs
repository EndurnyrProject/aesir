defmodule Aesir.ZoneServer.Integration.StoneBodyStateParityTest do
  @moduledoc """
  Petrification through the real status lifecycle: the wait shows the petrifying body
  state, running out starts Stone with the remaining duration and shows the petrified
  body state, live broadcasts and resynchronisation agree, and only a natural expiry
  petrifies.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.UnitStateChange
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager

  @petrifying 6
  @petrified 1

  setup do
    _observer = start_player_session(position: {150, 150})
    mob = start_mob_session(position: {152, 150}, max_hp: 1_000)
    clear_packet_inbox()
    %{mob: mob.unit_id}
  end

  defp petrify(mob_id) do
    :ok =
      Interpreter.apply_status(:mob, mob_id, :sc_stonewait,
        duration: 17_000,
        state: %{delay: 5_000},
        bypass_resistance: true
      )
  end

  defp run_out(mob_id, status_id) do
    StatusStorage.update_status(:mob, mob_id, status_id, fn entry ->
      %{entry | expires_at: System.monotonic_time(:millisecond) - 1}
    end)

    StatusTickManager.force_tick()
  end

  defp assert_body_state(mob_id, body_state) do
    assert_receive {:packet_sent, %UnitStateChange{unit_id: ^mob_id, body_state: ^body_state}, _},
                   1_000

    assert StatusDisplay.spawn_state(:mob, mob_id).body_state == body_state
    assert StatusDisplay.state_packet(:mob, mob_id).body_state == body_state
  end

  test "the wait shows petrifying, then running out petrifies with the rest", %{mob: mob_id} do
    petrify(mob_id)
    assert_body_state(mob_id, @petrifying)

    run_out(mob_id, :sc_stonewait)
    assert_body_state(mob_id, @petrified)

    stone = StatusStorage.get_status(:mob, mob_id, :sc_stone)
    assert stone.val3 == 12_000
    assert stone.expires_at - stone.started_at == 12_000
    refute StatusStorage.has_status?(:mob, mob_id, :sc_stonewait)
  end

  test "a 100 ms wait petrifies on its own deadline", %{mob: mob_id} do
    :ok =
      Interpreter.apply_status(:mob, mob_id, :sc_stonewait,
        duration: 12_100,
        bypass_resistance: true
      )

    wait = StatusStorage.get_status(:mob, mob_id, :sc_stonewait)
    assert wait.expires_at - wait.started_at == 100

    assert_body_state(mob_id, @petrified)
    stone = StatusStorage.get_status(:mob, mob_id, :sc_stone)
    assert (stone.started_at - wait.expires_at) in 0..50
    assert stone.next_tick_at - stone.started_at == 5_000
    assert stone.expires_at - stone.started_at == 12_000
  end

  test "a cured wait never petrifies", %{mob: mob_id} do
    petrify(mob_id)
    assert_body_state(mob_id, @petrifying)

    Interpreter.remove_status(:mob, mob_id, :sc_stonewait)
    assert_body_state(mob_id, 0)

    StatusTickManager.force_tick()
    refute_eventually(fn -> StatusStorage.has_status?(:mob, mob_id, :sc_stone) end)
  end

  test "a replaced wait's stale expiry does not petrify the replacement", %{mob: mob_id} do
    petrify(mob_id)
    stale = StatusStorage.get_status(:mob, mob_id, :sc_stonewait)
    Interpreter.remove_status(:mob, mob_id, :sc_stonewait)
    petrify(mob_id)

    refute Interpreter.expire_status_if_current(:mob, mob_id, :sc_stonewait, stale)
    assert StatusStorage.has_status?(:mob, mob_id, :sc_stonewait)
    refute StatusStorage.has_status?(:mob, mob_id, :sc_stone)
  end

  test "petrifying a petrified target cures it instead", %{mob: mob_id} do
    petrify(mob_id)
    run_out(mob_id, :sc_stonewait)
    assert_body_state(mob_id, @petrified)

    petrify(mob_id)

    assert_body_state(mob_id, 0)
    refute StatusStorage.has_status?(:mob, mob_id, :sc_stone)
    refute StatusStorage.has_status?(:mob, mob_id, :sc_stonewait)
  end
end
