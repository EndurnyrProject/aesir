defmodule Aesir.ZoneServer.Unit.Player.Handlers.HealthHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Packets.ZcNotifyCastCancel
  alias Aesir.ZoneServer.Packets.ZcParChange
  alias Aesir.ZoneServer.Packets.ZcResurrection
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # SP_HP / SP_SP / SP_MAXHP / SP_MAXSP param ids
  @sp_hp 5

  setup :set_mimic_from_context

  setup do
    Mimic.copy(CharacterPersistence)
    Mimic.copy(MovementHandler)
    Mimic.copy(StatusInterpreter)

    stub(StatusInterpreter, :on_damage, fn _, _, _ -> :ok end)
    stub(UnitRegistry, :update_unit_state, fn _, _, _ -> :ok end)
    stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
    stub(SpatialIndex, :remove_player, fn _ -> :ok end)
    stub(SpatialIndex, :clear_visibility, fn _ -> :ok end)
    stub(SpatialIndex, :add_player, fn _, _, _, _ -> :ok end)
    stub(MovementHandler, :handle_visibility_update, fn game_state -> game_state end)

    :ok
  end

  describe "damaged_hp/2" do
    test "subtracts damage and clamps at 0" do
      assert HealthHandler.damaged_hp(100, 30) == 70
      assert HealthHandler.damaged_hp(20, 50) == 0
    end
  end

  describe "apply_damage/3" do
    test "reduces HP and pushes an SP_HP update when the player survives" do
      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_damage(30, 2001, build_state(100, :idle))

      assert game_state.stats.current_state.hp == 70
      assert game_state.action_state == :idle
      assert_received {:send_packet, %ZcParChange{var_id: @sp_hp, value: 70}}
    end

    test "invokes status on_damage with post-damage HP populated" do
      test_pid = self()

      stub(StatusInterpreter, :on_damage, fn :player, char_id, damage_info ->
        send(test_pid, {:on_damage_called, char_id, damage_info})
        :ok
      end)

      HealthHandler.apply_damage(30, 2001, build_state(100, :idle))

      assert_received {:on_damage_called, 1, damage_info}
      assert damage_info.damage == 30
      assert damage_info.hp_after == 70
      assert damage_info.max_hp == 100
    end

    test "kills the player and marks them dead when HP reaches 0" do
      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_damage(150, 2001, build_state(100, :idle))

      assert game_state.stats.current_state.hp == 0
      assert game_state.action_state == :dead
      assert_received {:send_packet, %ZcParChange{var_id: @sp_hp, value: 0}}
    end

    test "ignores damage on an already dead player" do
      state = build_state(0, :dead)

      assert {:noreply, ^state} = HealthHandler.apply_damage(50, 2001, state)
      refute_received {:send_packet, _}
    end

    test "ignores non-positive damage" do
      state = build_state(100, :idle)

      assert {:noreply, ^state} = HealthHandler.apply_damage(0, 2001, state)
    end

    test "interrupts a survivable cast in the variable phase" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet, _opts -> :ok end)

      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_damage(30, 2001, casting_state(-100))

      assert game_state.action_state == :idle
      assert_received {:to_player, %ZcNotifyCastCancel{gid: 1}}
    end

    test "does not interrupt a survivable cast in the fixed phase" do
      reject(&Broadcast.to_player/2)

      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_damage(30, 2001, casting_state(60_000))

      assert game_state.action_state == :casting
      refute_received {:to_player, %ZcNotifyCastCancel{}}
    end
  end

  describe "handle_restart/2" do
    test "respawns a dead player at full HP/SP and stands them up" do
      {:noreply, %{game_state: game_state}} =
        HealthHandler.handle_restart(0, build_state(0, :dead))

      assert game_state.action_state == :idle
      assert game_state.stats.current_state.hp == 100
      assert game_state.stats.current_state.sp == 50
      assert_received {:send_packet, %ZcParChange{var_id: @sp_hp, value: 100}}
      assert_received {:send_packet, %ZcResurrection{gid: 100}}
    end

    test "does nothing when respawn is requested by a living player" do
      state = build_state(100, :idle)

      assert {:noreply, ^state} = HealthHandler.handle_restart(0, state)
    end

    test "disconnects the session on char-select (type 1)" do
      state = build_state(100, :idle)

      assert {:stop, :normal, ^state} = HealthHandler.handle_restart(1, state)
    end
  end

  # A live :casting state whose phase is driven by `fixed_offset`: negative =
  # variable phase, positive = fixed phase.
  defp casting_state(fixed_offset) do
    state = build_state(100, :idle)
    now = System.monotonic_time(:millisecond)
    token = make_ref()
    timer_ref = Process.send_after(self(), {:cast_complete, token}, 60_000)

    context = %{
      skill_id: 14,
      skill_level: 10,
      target: :self,
      element: :water,
      started_at: now,
      fixed_until: now + fixed_offset,
      total_until: now + 60_000,
      timer_ref: timer_ref,
      token: token,
      interruptible: true
    }

    {:ok, casting} = PlayerState.transition_to(state.game_state, :casting, context)
    %{state | game_state: casting}
  end

  defp build_state(hp, action_state) do
    stats = %Stats{
      current_state: %CurrentState{hp: hp, sp: 10},
      derived_stats: %DerivedStats{max_hp: 100, max_sp: 50, aspd: 150}
    }

    game_state = %PlayerState{
      character_id: 1,
      account_id: 100,
      action_state: action_state,
      x: 50,
      y: 50,
      map_name: "prontera",
      visible_players: MapSet.new(),
      stats: stats
    }

    %{
      game_state: game_state,
      connection_pid: self()
    }
  end
end
