defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerWarpTest do
  @moduledoc """
  `handle_map_loaded/1` — both the `:warp` and initial-entry branches.

  Covers the on-spawn entry trigger (rAthena `OnTouch` on-spawn): when a player
  loads into a map whose spawn cell sits inside a warp's `xs/ys` area, the warp
  fires. Also covers the cooldown reset: `last_warp_at` is cleared on every map
  load so a warp that triggered the load cycle can't suppress the on-spawn fire
  on the destination.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.MapLoaded
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_from_context

  setup do
    Mimic.copy(Warps)
    stub(Warps, :for_map, fn _ -> :error end)
    :ok
  end

  describe "handle_map_loaded :warp branch" do
    test "MapLoaded after a warp respawns the player without re-syncing inventory/skills/stats" do
      game_state = %PlayerState{
        character_id: 1000,
        map_name: "geffen",
        x: 100,
        y: 120,
        pending_map_load: :warp
      }

      state = %{game_state: game_state, connection_pid: self()}

      assert {:noreply, new_state} = PacketHandler.handle_message(%MapLoaded{}, state)

      assert new_state.game_state.pending_map_load == nil
      assert_received :respawn_after_warp
      refute_received :spawn_player
      refute_received {:send, :bulk, _}
      refute_received {:send, :gameplay, _}
    end

    test "a spawn cell inside a warp area re-fires the warp on map load" do
      warp = warp_at("geffen", 100, 120, xs: 1, ys: 1)
      stub(Warps, :for_map, fn "geffen" -> {:ok, [warp]} end)

      game_state = %PlayerState{
        character_id: 1000,
        map_name: "geffen",
        x: 100,
        y: 120,
        pending_map_load: :warp,
        last_warp_at: System.monotonic_time(:millisecond)
      }

      state = %{game_state: game_state, connection_pid: self()}

      assert {:noreply, new_state} = PacketHandler.handle_message(%MapLoaded{}, state)

      assert_received {:"$gen_cast", {:warp, "izlude", 150, 190}}
      assert new_state.game_state.last_warp_at == nil
    end

    test "a spawn cell outside any warp area casts nothing on map load" do
      game_state = %PlayerState{
        character_id: 1000,
        map_name: "geffen",
        x: 100,
        y: 120,
        pending_map_load: :warp
      }

      state = %{game_state: game_state, connection_pid: self()}

      assert {:noreply, _new_state} = PacketHandler.handle_message(%MapLoaded{}, state)

      refute_received {:"$gen_cast", {:warp, _, _, _}}
    end
  end

  describe "handle_map_loaded initial-entry branch" do
    test "a spawn cell inside a warp area fires the warp on initial entry" do
      warp = warp_at("prontera", 50, 50, xs: 1, ys: 1)
      stub(Warps, :for_map, fn "prontera" -> {:ok, [warp]} end)

      game_state = PlayerState.new(character("prontera", 50, 50))
      state = %{game_state: game_state, connection_pid: self()}

      assert {:noreply, new_state} = PacketHandler.handle_message(%MapLoaded{}, state)

      assert_received {:"$gen_cast", {:warp, "izlude", 150, 190}}
      assert_received :spawn_player
      assert new_state.game_state.last_warp_at == nil
    end

    test "a spawn cell outside any warp area casts nothing on initial entry" do
      game_state = PlayerState.new(character("prontera", 50, 50))
      state = %{game_state: game_state, connection_pid: self()}

      assert {:noreply, _new_state} = PacketHandler.handle_message(%MapLoaded{}, state)

      refute_received {:"$gen_cast", {:warp, _, _, _}}
    end

    test "clears last_warp_at set by a prior warp before the on-spawn check" do
      warp = warp_at("prontera", 50, 50, xs: 1, ys: 1)
      stub(Warps, :for_map, fn "prontera" -> {:ok, [warp]} end)

      game_state =
        PlayerState.new(character("prontera", 50, 50))
        |> Map.put(:last_warp_at, System.monotonic_time(:millisecond))

      state = %{game_state: game_state, connection_pid: self()}

      assert {:noreply, new_state} = PacketHandler.handle_message(%MapLoaded{}, state)

      assert_received {:"$gen_cast", {:warp, "izlude", 150, 190}}
      assert new_state.game_state.last_warp_at == nil
    end
  end

  defp warp_at(map, x, y, opts) do
    xs = Keyword.get(opts, :xs, 0)
    ys = Keyword.get(opts, :ys, 0)

    %Warp{
      id: "test_warp_#{map}_#{x}_#{y}",
      map: map,
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

  defp character(map_name, x, y) do
    %Character{
      id: 1001,
      account_id: 100,
      name: "Tester",
      last_map: map_name,
      last_x: x,
      last_y: y,
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
