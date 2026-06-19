defmodule Aesir.ZoneServer.Unit.Player.Handlers.MovementHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Packets.ZcNotifyCastCancel
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :set_mimic_from_context

  setup do
    Mimic.copy(MapCache)
    Mimic.copy(Pathfinding)
    Mimic.copy(SpatialIndex)
    Mimic.copy(Broadcast)

    stub(MapCache, :get, fn "prontera" -> {:ok, %{width: 200, height: 200}} end)
    stub(Pathfinding, :find_path, fn _map, {50, 50}, {51, 50} -> {:ok, [{50, 50}, {51, 50}]} end)
    stub(SpatialIndex, :get_visible_players, fn _ -> [] end)
    stub(Broadcast, :to_player, fn _, _ -> :ok end)
    stub(Broadcast, :to_in_range, fn _, _, _, _, _, _ -> :ok end)

    :ok
  end

  describe "handle_request_move/4" do
    test "cancels an in-flight cast before starting to move" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1, packet -> send(test_pid, {:to_player, packet}) end)

      {:noreply, new_state} = MovementHandler.handle_request_move(casting_state(), 51, 50)

      assert new_state.game_state.movement_state == :moving
      assert_received {:to_player, %ZcNotifyCastCancel{gid: 1}}
    end
  end

  defp casting_state do
    game_state = PlayerState.new(character())
    token = make_ref()
    now = System.monotonic_time(:millisecond)
    timer_ref = Process.send_after(self(), {:cast_complete, token}, 60_000)

    context = %{
      skill_id: 14,
      skill_level: 10,
      target: :self,
      element: :water,
      started_at: now,
      fixed_until: now + 60_000,
      total_until: now + 60_000,
      timer_ref: timer_ref,
      token: token,
      interruptible: true
    }

    {:ok, casting} = PlayerState.transition_to(game_state, :casting, context)

    %{game_state: casting, connection_pid: self()}
  end

  defp character do
    %Character{
      id: 1,
      account_id: 100,
      name: "Mover",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }
  end
end
