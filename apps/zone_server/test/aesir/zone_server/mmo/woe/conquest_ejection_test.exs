defmodule Aesir.ZoneServer.Mmo.Woe.ConquestEjectionTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestWait
  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.MapMove
  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Mmo.Woe.Server
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Player.GuildSync
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @approval_skill_id 10_000
  @new_owner_guild_id 7

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()

    server = start_supervised!(Server)

    Mimic.copy(Persistence)
    Mimic.allow(Announcement, self(), server)
    Mimic.allow(Persistence, self(), server)
    Mimic.allow(Manager, self(), server)

    stub(Announcement, :to_all, fn _opts -> :ok end)
    stub(GuildSync, :sync, fn _previous, _current -> :ok end)
    stub(Persistence, :persist, fn _castle_id, _guild_id -> :ok end)
    stub(Persistence, :persist_economy, fn _castle_id, _state -> :ok end)

    stub(Manager, :get, fn guild_id ->
      {:ok,
       %State{
         guild_id: guild_id,
         name: "NewOwner",
         master_char_id: 1,
         learned_skills: %{@approval_skill_id => 1}
       }}
    end)

    :ok
  end

  test "successful conquest queues every registered castle outsider including guildless pending loads" do
    castle = hd(CastleDb.all())
    live_emperium_id = 90_001

    recipients = for id <- 1..4, into: %{}, do: {id, collector(id)}
    on_exit(fn -> Enum.each(recipients, fn {_id, pid} -> Process.exit(pid, :kill) end) end)

    register_player(1, castle.map, @new_owner_guild_id, nil, recipients[1])
    register_player(2, castle.map, 8, nil, recipients[2])
    register_player(3, castle.map, 0, :warp, recipients[3])
    register_player(4, "prontera", 8, nil, recipients[4])

    :ok = CastleStore.set_siege(castle.id, true)
    :ok = CastleStore.set_emperium(castle.id, live_emperium_id)

    assert :ok =
             Lifecycle.publish_death(:mob, live_emperium_id, castle.map, %{
               attacker: {:player, 99},
               character_id: 99,
               guild_id: @new_owner_guild_id
             })

    assert_receive {:cast, 2,
                    {:"$gen_cast", {:movement, {:castle_ejection, castle_id, source_map, 1}}}},
                   200

    assert castle_id == castle.id
    assert source_map == castle.map

    assert_receive {:cast, 3,
                    {:"$gen_cast", {:movement, {:castle_ejection, ^castle_id, ^source_map, 1}}}},
                   200

    refute_receive {:cast, 1, _message}, 100
    refute_receive {:cast, 4, _message}, 100
  end

  test "valid current conquest ejects an outsider to the session's current save point" do
    castle = hd(CastleDb.all())
    capture_epoch = claim_castle(castle.id, @new_owner_guild_id)
    state = session_state(10, castle.map, 8, save_point: {"prontera", 150, 150})
    :ok = UnitRegistry.register_player(state.game_state, self())

    assert {:noreply, ejected} =
             WarpHandler.handle_castle_ejection(
               castle.id,
               castle.map,
               capture_epoch,
               state
             )

    assert ejected.game_state.map_name == "prontera"
    assert {ejected.game_state.x, ejected.game_state.y} == {150, 150}
    assert ejected.game_state.pending_map_load == :warp

    assert_received {:send, :control, {:map_move, %MapMove{map_name: "prontera", x: 150, y: 150}}}
  end

  test "stale, invalid, moved, and current-owner ejection requests are no-ops" do
    castle = hd(CastleDb.all())
    capture_epoch = claim_castle(castle.id, @new_owner_guild_id)
    outsider = session_state(11, castle.map, 8, save_point: {"prontera", 150, 150})

    moved = %{outsider | game_state: %{outsider.game_state | map_name: "prontera"}}
    owner = %{outsider | game_state: %{outsider.game_state | guild_id: @new_owner_guild_id}}

    for {state, epoch} <- [{moved, capture_epoch}, {owner, capture_epoch}, {outsider, 0}] do
      assert {:noreply, ^state} =
               WarpHandler.handle_castle_ejection(castle.id, castle.map, epoch, state)
    end

    :ok = CastleStore.set_siege(castle.id, false)

    assert {:noreply, ^outsider} =
             WarpHandler.handle_castle_ejection(
               castle.id,
               castle.map,
               capture_epoch,
               outsider
             )

    refute_received {:send, :control, {:map_move, _packet}}
  end

  test "an invalid current save point keeps the outsider in place and retains warp logging" do
    castle = hd(CastleDb.all())
    capture_epoch = claim_castle(castle.id, @new_owner_guild_id)
    state = session_state(12, castle.map, 8, save_point: {"missing_save_map", 1, 2})

    log =
      capture_log(fn ->
        assert {:noreply, ^state} =
                 WarpHandler.handle_castle_ejection(
                   castle.id,
                   castle.map,
                   capture_epoch,
                   state
                 )
      end)

    assert log =~ "Warp failed for 12 to missing_save_map (1, 2): :map_not_found"
    refute_received {:send, :control, {:map_move, _packet}}
  end

  test "a live objective claim without a valid conqueror does not queue ejection" do
    castle = hd(CastleDb.all())
    live_emperium_id = 90_002
    recipient = collector(20)
    on_exit(fn -> Process.exit(recipient, :kill) end)
    register_player(20, castle.map, 8, nil, recipient)

    :ok = CastleStore.set_siege(castle.id, true)
    :ok = CastleStore.set_emperium(castle.id, live_emperium_id)
    assert :ok = Lifecycle.publish_death(:mob, live_emperium_id, castle.map, nil)
    assert_eventually(fn -> CastleStore.get(castle.id).epoch == 1 end)

    refute_receive {:cast, 20, _message}, 100
  end

  test "castle ejection moves a corpse without reviving it or changing experience" do
    castle = hd(CastleDb.all())
    capture_epoch = claim_castle(castle.id, @new_owner_guild_id)
    state = session_state(11, castle.map, 8, save_point: {"prontera", 150, 150})

    dead_game_state =
      state.game_state
      |> put_in([Access.key(:stats), Access.key(:current_state), Access.key(:hp)], 0)
      |> Map.put(:action_state, :dead)

    state = %{state | game_state: dead_game_state}
    experience = dead_game_state.stats.progression
    :ok = UnitRegistry.register_player(dead_game_state, self())

    assert {:noreply, ejected} =
             WarpHandler.handle_castle_ejection(
               castle.id,
               castle.map,
               capture_epoch,
               state
             )

    assert ejected.game_state.map_name == "prontera"
    assert ejected.game_state.action_state == :dead
    assert ejected.game_state.stats.current_state.hp == 0
    assert ejected.game_state.stats.progression == experience
  end

  defp register_player(character_id, map_name, guild_id, pending_map_load, pid) do
    state = %PlayerState{
      character_id: character_id,
      account_id: character_id + 1_000,
      character_name: "Player#{character_id}",
      map_name: map_name,
      guild_id: guild_id,
      pending_map_load: pending_map_load
    }

    :ok = UnitRegistry.register_player(state, pid)
  end

  defp collector(id) do
    test_pid = self()

    spawn(fn ->
      receive do
        message -> send(test_pid, {:cast, id, message})
      end
    end)
  end

  defp session_state(character_id, map_name, guild_id, opts) do
    {save_map, save_x, save_y} = Keyword.fetch!(opts, :save_point)

    game_state =
      %Character{
        id: character_id,
        account_id: character_id + 1_000,
        name: "Player#{character_id}",
        class: 0,
        base_level: 1,
        job_level: 1,
        hp: 100,
        sp: 50,
        last_map: map_name,
        last_x: 150,
        last_y: 150,
        save_map: save_map,
        save_x: save_x,
        save_y: save_y,
        guild_id: guild_id
      }
      |> PlayerState.new()

    %SessionState{game_state: game_state, connection_pid: self()}
  end

  defp claim_castle(castle_id, guild_id) do
    emperium_id = System.unique_integer([:positive])
    :ok = CastleStore.set_siege(castle_id, true)
    :ok = CastleStore.set_emperium(castle_id, emperium_id)
    assert {:ok, state} = CastleStore.claim_break(castle_id, emperium_id, guild_id)
    state.epoch
  end
end
