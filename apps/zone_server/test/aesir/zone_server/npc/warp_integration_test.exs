defmodule Aesir.ZoneServer.Npc.WarpIntegrationTest do
  @moduledoc """
  End-to-end NPC warp flow at the session level (no real client).

  Proves the full on-touch -> warp -> MapLoaded -> respawn cycle:
    1. A walking player steps into a warp's `xs/ys` trigger area -> the on-touch
       hook casts `{:movement, {:warp, to_map, to_x, to_y}}` and cancels the walk.
    2. `PlayerSession.handle_cast({:movement, {:warp, …}})` runs `WarpHandler.warp/4`, which
       tears the player down on the old map (`leave_current_map` -> spatial
       index + visibility cleared) and sends `MapMove` to the connection.
    3. On the `MapLoaded` ack, the player re-enters the destination map
       (`:respawn_after_warp` -> re-added to the spatial index) and the on-spawn
       warp check runs. A destination cell outside any warp area does not loop.
    4. An in-map teleport warp (same `to_map`) does not loop infinitely: the
       on-spawn check finds no warp at the destination cell.

  Drives the real `PlayerSession` -> `MovementHandler` -> `WarpHandler` ->
  `PacketHandler` path; only the I/O collaborators (map cache for the
  non-existent "izlude" destination, spatial index bookkeeping, broadcast) are
  stubbed. `prontera` uses the real map cache warmed by `TestEtsSetup`.
  """

  use ExUnit.Case, async: true
  use Mimic

  @moduletag :integration

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.MapMove
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"
  @char_id 1001

  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(Warps)
    # Default: no warps anywhere; each test opts in per map.
    stub(Warps, :for_map, fn _ -> :error end)

    # The destination "izlude" is not in the real map cache (only izlude_a/b/…
    # exist), so insert a minimal walkable map entry so `MapCache.get/1` and
    # `MapData.walkable?/3` resolve for both the verifier and `WarpHandler`.
    izlude = MapData.new("izlude", 200, 200)
    :ets.insert(EtsTable.table_for(:map_cache), {"izlude", izlude})

    # No other observers / mobs in range during the flow.
    stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
    stub(SpatialIndex, :get_units_in_range, fn _, _, _, _, _ -> [] end)
    stub(SpatialIndex, :get_visible_players, fn @char_id -> [] end)
    stub(Broadcast, :to_players, fn _, _, _ -> :ok end)
    stub(Broadcast, :subscribe_mob_despawns, fn _ -> :ok end)
    stub(Broadcast, :unsubscribe_mob_despawns, fn _ -> :ok end)
    stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _ -> :ok end)

    {:ok, %{character: character()}}
  end

  describe "cross-map warp end-to-end (prontera -> izlude)" do
    test "step into warp fires, old map tears down, MapMove sent, MapLoaded respawns on destination",
         %{character: character} do
      warp = warp_at(51, 50, xs: 1, ys: 1, to_map: "izlude", to_x: 150, to_y: 190)

      stub(Warps, :for_map, fn
        "prontera" -> {:ok, [warp]}
        _ -> :error
      end)

      # --- Stage 1: drive a movement tick into the warp's trigger area. ---
      game_state =
        PlayerState.new(character)
        |> Map.put(:walk_path, [{51, 50}, {52, 50}])
        |> Map.put(:movement_state, :moving)
        |> Map.put(:visible_warps, MapSet.new([Warp.Registry.entity_id(warp)]))

      register_player(game_state)

      state = %{game_state: game_state, connection_pid: self()}

      {:noreply, ticked_state} = PlayerSession.handle_info({:movement, :movement_tick}, state)

      # On-touch hook cast the warp to the session and cancelled the walk.
      assert_received {:"$gen_cast", {:movement, {:warp, "izlude", 150, 190}}}
      assert ticked_state.game_state.movement_state == :standing
      assert ticked_state.game_state.walk_path == []
      assert ticked_state.game_state.last_warp_at != nil

      # --- Stage 2: the {:movement, {:warp, …}} cast runs WarpHandler.warp/4. ----
      # `leave_current_map` must run: the player is removed from the spatial
      # index and its visibility pairs cleared, before the MapLoaded ack.
      expect(SpatialIndex, :remove_player, fn @char_id -> :ok end)
      expect(SpatialIndex, :clear_visibility, fn @char_id -> :ok end)

      {:noreply, warped_state} =
        PlayerSession.handle_cast({:movement, {:warp, "izlude", 150, 190}}, ticked_state)

      # MapMove carries the warp's destination coords.
      assert_received {:send, :control, {:map_move, %MapMove{map_name: "izlude", x: 150, y: 190}}}

      assert warped_state.game_state.map_name == "izlude"
      assert warped_state.game_state.x == 150
      assert warped_state.game_state.y == 190
      assert warped_state.game_state.pending_map_load == :warp

      # --- Stage 3: the client acks with MapLoaded. -----------------------
      # No warps on the destination -> on-spawn check fires nothing (no loop).
      {:noreply, loaded_state} = PacketHandler.handle_message(%MapLoaded{}, warped_state)

      assert loaded_state.game_state.pending_map_load == nil
      assert loaded_state.game_state.last_warp_at == nil
      assert_received :respawn_after_warp
      refute_received {:"$gen_cast", {:movement, {:warp, _, _, _}}}

      # --- Stage 4: :respawn_after_warp re-enters the destination map. ----
      expect(SpatialIndex, :add_player, fn @char_id, 150, 190, "izlude" -> :ok end)

      {:noreply, _final_state} =
        PlayerSession.handle_info(:respawn_after_warp, loaded_state)
    end
  end

  describe "in-map teleport warp does not loop" do
    test "a same-map warp whose destination is outside every warp area fires exactly once",
         %{character: character} do
      # prontera -> prontera teleport; dest (200, 200) is outside the (51,50)
      # trigger area, so the on-spawn check after MapLoaded finds no warp.
      warp =
        warp_at(51, 50, xs: 1, ys: 1, to_map: "prontera", to_x: 200, to_y: 200)

      stub(Warps, :for_map, fn
        "prontera" -> {:ok, [warp]}
        _ -> :error
      end)

      game_state =
        PlayerState.new(character)
        |> Map.put(:walk_path, [{51, 50}, {52, 50}])
        |> Map.put(:movement_state, :moving)
        |> Map.put(:visible_warps, MapSet.new([Warp.Registry.entity_id(warp)]))

      register_player(game_state)

      state = %{game_state: game_state, connection_pid: self()}

      # Stage 1: step into the warp -> cast {:movement, {:warp, "prontera", 200, 200}}.
      {:noreply, ticked_state} = PlayerSession.handle_info({:movement, :movement_tick}, state)

      assert_received {:"$gen_cast", {:movement, {:warp, "prontera", 200, 200}}}

      # Stage 2: the warp cast relocates within the same map. `leave_current_map`
      # still runs (the player vanishes from observers and re-enters at the new
      # cell on MapLoaded).
      expect(SpatialIndex, :remove_player, fn @char_id -> :ok end)
      expect(SpatialIndex, :clear_visibility, fn @char_id -> :ok end)

      {:noreply, warped_state} =
        PlayerSession.handle_cast({:movement, {:warp, "prontera", 200, 200}}, ticked_state)

      assert_received {:send, :control,
                       {:map_move, %MapMove{map_name: "prontera", x: 200, y: 200}}}

      assert warped_state.game_state.pending_map_load == :warp

      # Stage 3: MapLoaded -> clear cooldown -> on-spawn check at (200, 200).
      # (200, 200) is outside the warp's [50-52, 49-51] area -> no cast -> no loop.
      {:noreply, loaded_state} = PacketHandler.handle_message(%MapLoaded{}, warped_state)

      assert loaded_state.game_state.last_warp_at == nil
      assert_received :respawn_after_warp
      refute_received {:"$gen_cast", {:movement, {:warp, _, _, _}}}
    end
  end

  # --- helpers ---------------------------------------------------------------

  defp warp_at(x, y, opts) do
    struct!(
      Warp,
      Keyword.merge(
        [
          id: "test_warp_#{x}_#{y}",
          map: "prontera",
          to_map: "izlude",
          x: x,
          y: y,
          xs: 0,
          ys: 0,
          to_x: 150,
          to_y: 190,
          sprite: 45,
          name: "Izlude"
        ],
        opts
      )
    )
  end

  defp character do
    %Character{
      id: @char_id,
      account_id: 100,
      name: "Wanderer",
      last_map: @map,
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

  defp register_player(game_state) do
    UnitRegistry.register_unit(:player, @char_id, PlayerState, game_state, nil)
    SpatialIndex.add_unit(:player, @char_id, game_state.x, game_state.y, @map)
    Movement.drain_dirty(@map)
  end
end
