defmodule Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.Net.ActionRequest
  alias Aesir.Net.MoveStop
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :set_mimic_from_context

  setup do
    Mimic.copy(Interpreter)
    stub(Interpreter, :can_attack?, fn _type, _id -> true end)
    :ok
  end

  describe "handle_message/2 inbound ActionRequest dispatch" do
    test "an attack ActionRequest casts request_attack with the same target/action" do
      state = %{game_state: %PlayerState{character_id: 1000}}

      assert {:noreply, ^state} =
               PacketHandler.handle_message(%ActionRequest{target_id: 2000, action: 0}, state)

      assert_received {:"$gen_cast", {:request_attack, 2000, 0}}
    end

    test "a continuous-attack ActionRequest casts request_attack with action 7" do
      state = %{game_state: %PlayerState{character_id: 1000}}

      assert {:noreply, ^state} =
               PacketHandler.handle_message(%ActionRequest{target_id: 2000, action: 7}, state)

      assert_received {:"$gen_cast", {:request_attack, 2000, 7}}
    end

    test "a sit ActionRequest does not cast request_attack" do
      state = %{game_state: %PlayerState{character_id: 1000}}

      capture_log(fn ->
        assert {:noreply, ^state} =
                 PacketHandler.handle_message(%ActionRequest{target_id: 0, action: 2}, state)
      end)

      refute_received {:"$gen_cast", {:request_attack, _, _}}
    end
  end

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

  describe "handle_attack_request/3 status gating" do
    defp restricted_state(action_state) do
      game_state = %PlayerState{
        character_id: 1000,
        x: 10,
        y: 10,
        action_state: action_state,
        last_attack_timestamp: 0,
        act_delay_until: 0,
        stats: %{derived_stats: %{aspd: 150}}
      }

      %{game_state: game_state, connection_pid: self()}
    end

    test "a no_attack player making a discrete swing does not attack nor enter :attacking" do
      stub(Interpreter, :can_attack?, fn :player, 1000 -> false end)
      state = restricted_state(:idle)

      assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 0)

      assert returned.game_state.action_state == :idle
      refute_received {:send, :gameplay, {:move_stop, %MoveStop{}}}
    end

    test "a no_attack player approaching a target is halted with a MoveStop and dropped to idle" do
      stub(Interpreter, :can_attack?, fn :player, 1000 -> false end)
      state = restricted_state(:combat_moving)

      assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 7)

      assert returned.game_state.action_state == :idle
      assert returned.game_state.combat_target_id == nil
      assert_received {:send, :gameplay, {:move_stop, %MoveStop{gid: 1000, x: 10, y: 10}}}
    end

    test "an unafflicted player proceeds to the range check as before" do
      state = restricted_state(:idle)

      log =
        capture_log(fn ->
          assert {:noreply, _returned} = CombatActionHandler.handle_attack_request(state, 2000, 0)
          send(self(), :done)
        end)

      assert_received :done
      assert log =~ "range"
      refute_received {:send, :gameplay, {:move_stop, %MoveStop{}}}
    end
  end

  describe "target acquisition gate" do
    defp acquire_state(map_name) do
      game_state = %PlayerState{
        character_id: 1000,
        x: 10,
        y: 10,
        map_name: map_name,
        action_state: :idle,
        last_attack_timestamp: 0,
        act_delay_until: 0,
        stats: %{derived_stats: %{aspd: 150}}
      }

      %{game_state: game_state, connection_pid: self()}
    end

    test "an attack on a target on a different map is rejected without attacking or chasing" do
      reject(&Combat.execute_attack/3)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {12, 12, "geffen"}}
      end)

      state = acquire_state("prontera")

      capture_log(fn ->
        assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 7)
        assert returned.game_state.action_state == :idle
        send(self(), :done)
      end)

      assert_received :done
      refute_received {:send, :gameplay, {:move_stop, _}}
    end

    test "an attack on a target beyond view range is rejected without attacking or chasing" do
      reject(&Combat.execute_attack/3)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {100, 100, "prontera"}}
      end)

      state = acquire_state("prontera")

      capture_log(fn ->
        assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 7)
        assert returned.game_state.action_state == :idle
        send(self(), :done)
      end)

      assert_received :done
      refute_received {:send, :gameplay, {:move_stop, _}}
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
