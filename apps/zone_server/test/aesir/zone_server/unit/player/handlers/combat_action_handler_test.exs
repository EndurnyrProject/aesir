defmodule Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandlerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  describe "after-cast act delay gate" do
    defp attack_ready_state(act_delay_until) do
      game_state = %PlayerState{
        character_id: 1000,
        x: 10,
        y: 10,
        action_state: :idle,
        last_attack_timestamp: 0,
        act_delay_until: act_delay_until,
        stats: %{derived_stats: %{aspd: 150}}
      }

      %{game_state: game_state}
    end

    test "a melee attack is blocked (no range check) while act-delayed" do
      future = System.monotonic_time(:millisecond) + 60_000
      state = attack_ready_state(future)

      log =
        capture_log(fn ->
          assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 0)
          assert returned.game_state.action_state == :idle
          send(self(), :done)
        end)

      assert_received :done
      refute log =~ "range"
    end

    test "a melee attack proceeds to the range check once the act delay is clear" do
      state = attack_ready_state(0)

      log =
        capture_log(fn ->
          assert {:noreply, _returned} = CombatActionHandler.handle_attack_request(state, 2000, 0)
          send(self(), :done)
        end)

      assert_received :done
      assert log =~ "range"
    end
  end

  describe "get_optimal_attack_position/3" do
    test "returns current position when already in range" do
      attacker_pos = {100, 100}
      target_pos = {101, 101}
      weapon_range = 2

      result =
        CombatActionHandler.get_optimal_attack_position(
          attacker_pos,
          target_pos,
          weapon_range
        )

      assert result == {100, 100}
    end

    test "calculates position for melee range (1 cell)" do
      attacker_pos = {100, 100}
      target_pos = {105, 105}
      weapon_range = 1

      {optimal_x, optimal_y} =
        CombatActionHandler.get_optimal_attack_position(
          attacker_pos,
          target_pos,
          weapon_range
        )

      # Should move to within 1 cell of target
      distance = max(abs(optimal_x - 105), abs(optimal_y - 105))
      assert distance <= 1
    end

    test "calculates position for spear range (2 cells)" do
      attacker_pos = {100, 100}
      target_pos = {110, 110}
      weapon_range = 2

      {optimal_x, optimal_y} =
        CombatActionHandler.get_optimal_attack_position(
          attacker_pos,
          target_pos,
          weapon_range
        )

      # Should move to within 2 cells of target
      distance = max(abs(optimal_x - 110), abs(optimal_y - 110))
      assert distance <= 2
    end

    test "calculates position for ranged weapon (9 cells)" do
      attacker_pos = {100, 100}
      target_pos = {120, 120}
      weapon_range = 9

      {optimal_x, optimal_y} =
        CombatActionHandler.get_optimal_attack_position(
          attacker_pos,
          target_pos,
          weapon_range
        )

      # Should move to within 9 cells of target
      distance = max(abs(optimal_x - 120), abs(optimal_y - 120))
      assert distance <= 9
    end

    test "handles horizontal movement" do
      attacker_pos = {100, 100}
      target_pos = {110, 100}
      weapon_range = 1

      {optimal_x, optimal_y} =
        CombatActionHandler.get_optimal_attack_position(
          attacker_pos,
          target_pos,
          weapon_range
        )

      # Should move horizontally to within 1 cell
      assert optimal_y == 100
      assert abs(optimal_x - 110) <= 1
    end

    test "handles vertical movement" do
      attacker_pos = {100, 100}
      target_pos = {100, 110}
      weapon_range = 1

      {optimal_x, optimal_y} =
        CombatActionHandler.get_optimal_attack_position(
          attacker_pos,
          target_pos,
          weapon_range
        )

      # Should move vertically to within 1 cell
      assert optimal_x == 100
      assert abs(optimal_y - 110) <= 1
    end

    test "handles same position edge case" do
      attacker_pos = {100, 100}
      target_pos = {100, 100}
      weapon_range = 1

      result =
        CombatActionHandler.get_optimal_attack_position(
          attacker_pos,
          target_pos,
          weapon_range
        )

      assert result == {100, 100}
    end
  end
end
