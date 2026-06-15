defmodule Aesir.ZoneServer.Unit.Player.Handlers.HealthHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Packets.ZcParChange
  alias Aesir.ZoneServer.Packets.ZcResurrection
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
