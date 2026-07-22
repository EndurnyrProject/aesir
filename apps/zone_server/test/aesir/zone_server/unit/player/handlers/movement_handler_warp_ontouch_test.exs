defmodule Aesir.ZoneServer.Unit.Player.Handlers.MovementHandlerWarpOntouchTest do
  @moduledoc """
  On-touch warp trigger hook in `MovementHandler.step_player/4`.

  rAthena fires `npc_touch_area_allnpc` on cell-enter (the cell the player just
  stepped onto), so the hook runs after `Movement.set_position/4` moves the
  player to `(next_x, next_y)` and after `handle_visibility_update/1`.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character

  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map_name "prontera"

  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(Warps)
    stub(Warps, :for_map, fn _ -> :error end)
    :ok
  end

  describe "on-touch warp trigger during step_player" do
    test "stepping into a warp area casts {:movement, {:warp, to_map, to_x, to_y}} and cancels the walk" do
      warp = warp_at(51, 50, xs: 1, ys: 1)
      stub(Warps, :for_map, fn "prontera" -> {:ok, [warp]} end)

      game_state =
        player_state()
        |> Map.put(:walk_path, [{51, 50}, {52, 50}])
        |> Map.put(:movement_state, :moving)
        |> Map.put(:visible_warps, MapSet.new([Warp.Registry.entity_id(warp)]))

      register_player(game_state)

      {:noreply, new_state} = MovementHandler.handle_movement_tick(%{game_state: game_state})

      assert_received {:"$gen_cast", {:movement, {:warp, "izlude", 150, 190}}}

      assert new_state.game_state.movement_state == :standing
      assert new_state.game_state.walk_path == []
      assert new_state.game_state.last_warp_at != nil
    end

    test "stepping outside every warp area casts nothing and the walk continues" do
      # Warp placed far away — its area never contains the step cell (51,50).
      warp = warp_at(200, 200, xs: 1, ys: 1)
      stub(Warps, :for_map, fn "prontera" -> {:ok, [warp]} end)

      game_state =
        player_state()
        |> Map.put(:walk_path, [{51, 50}, {52, 50}])
        |> Map.put(:movement_state, :moving)
        |> Map.put(:visible_warps, MapSet.new())

      register_player(game_state)

      {:noreply, new_state} = MovementHandler.handle_movement_tick(%{game_state: game_state})

      refute_received {:"$gen_cast", {:movement, {:warp, _, _, _}}}

      assert new_state.game_state.movement_state == :moving
      assert new_state.game_state.walk_path == [{52, 50}]
      assert new_state.game_state.last_warp_at == nil
    end

    @tag :skip
    test "stepping into a warp area within the cooldown casts nothing (no re-fire)" do
      warp = warp_at(51, 50, xs: 1, ys: 1)
      stub(Warps, :for_map, fn "prontera" -> {:ok, [warp]} end)

      game_state =
        player_state()
        |> Map.put(:walk_path, [{51, 50}, {52, 50}])
        |> Map.put(:movement_state, :moving)
        |> Map.put(:visible_warps, MapSet.new([Warp.Registry.entity_id(warp)]))
        |> Map.put(:last_warp_at, System.monotonic_time(:millisecond))

      register_player(game_state)

      {:noreply, new_state} = MovementHandler.handle_movement_tick(%{game_state: game_state})

      refute_received {:"$gen_cast", {:movement, {:warp, _, _, _}}}

      # Cooldown no-op: the walk continues as normal.
      assert new_state.game_state.movement_state == :moving
      assert new_state.game_state.walk_path == [{52, 50}]
    end
  end

  defp warp_at(x, y, opts) do
    xs = Keyword.get(opts, :xs, 0)
    ys = Keyword.get(opts, :ys, 0)

    %Warp{
      id: "test_warp",
      map: "prontera",
      to_map: "izlude",
      x: x,
      y: y,
      xs: xs,
      ys: ys,
      to_x: 150,
      to_y: 190,
      sprite: 45,
      name: "Izlude"
    }
  end

  defp player_state do
    PlayerState.new(character())
  end

  defp register_player(game_state) do
    char_id = game_state.character_id
    UnitRegistry.register_unit(:player, char_id, MovementHandler, game_state, nil)
    SpatialIndex.add_unit(:player, char_id, game_state.x, game_state.y, @map_name)
    Movement.drain_dirty(@map_name)
  end

  defp character do
    %Character{
      id: 1001,
      account_id: 100,
      name: "Mover",
      last_map: @map_name,
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
