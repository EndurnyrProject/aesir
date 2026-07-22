defmodule Aesir.ZoneServer.Npc.OnTouchTest do
  @moduledoc """
  End-to-end coverage of Task 10's OnTouch trigger areas: player movement
  checks the per-map touch rects (`Npc.Registry.touch_rects/1`) on every cell
  change and fires the owning NPC's `OnTouch` as an attached `Interaction`, or
  falls back to `on_talk/1` when the module declares a trigger area but no
  `OnTouch` label (rAthena warper behavior).

  Drives the real `PlayerSession.handle_info({:movement, :movement_tick}, ...)` ->
  `MovementHandler` path, mirroring `warp_integration_test.exs`'s
  movement-driven trigger pattern and `npc_visibility_test.exs`'s
  registry/flag fixture hygiene (the `:npc_session_flags` on_exit cleanup).
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"
  @char_id 9001

  defmodule TouchNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 60, y: 50, sprite: 58, name: "Toucher", trigger: {1, 1}}]

    @impl true
    def on_talk(ctx) do
      send(:on_touch_probe, {:talked, __MODULE__})
      ctx
    end

    @impl true
    def on_event("OnTouch", ctx) do
      send(:on_touch_probe, {:touched, __MODULE__})
      ctx
    end
  end

  defmodule WarperNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 70, y: 50, sprite: 45, name: "Warper", trigger: {0, 0}}]

    @impl true
    def on_talk(ctx) do
      send(:on_touch_probe, {:talked, __MODULE__})
      ctx
    end
  end

  defmodule OverlapNpcA do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 80, y: 50, sprite: 58, name: "OverlapA", trigger: {2, 0}}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTouch", ctx) do
      send(:on_touch_probe, {:touched, __MODULE__})
      ctx
    end
  end

  defmodule OverlapNpcB do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 82, y: 50, sprite: 58, name: "OverlapB", trigger: {2, 0}}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTouch", ctx) do
      send(:on_touch_probe, {:touched, __MODULE__})
      ctx
    end
  end

  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Process.register(self(), :on_touch_probe)
    NpcRegistry.reload([TouchNpc, WarperNpc, OverlapNpcA, OverlapNpcB])

    gids = Enum.map([TouchNpc, WarperNpc, OverlapNpcA, OverlapNpcB], &gid_for/1)

    on_exit(fn ->
      :persistent_term.erase(NpcRegistry)
      Enum.each(gids, &:ets.delete(:npc_session_flags, &1))
    end)

    stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
    stub(SpatialIndex, :get_units_in_range, fn _, _, _, _, _ -> [] end)
    stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)
    stub(Broadcast, :to_players, fn _, _, _ -> :ok end)
    stub(Warps, :for_map, fn _ -> :error end)

    :ok
  end

  describe "entering, staying, leaving and re-entering a trigger area" do
    test "fires once on entry, not while staying inside, again on re-entry" do
      gid = gid_for(TouchNpc)

      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:x, 57)
        |> Map.put(:y, 50)
        |> Map.put(:walk_path, [{58, 50}, {59, 50}, {60, 50}, {61, 50}, {62, 50}, {61, 50}])
        |> Map.put(:movement_state, :moving)

      register_player(game_state)

      state = %{game_state: game_state, connection_pid: self(), interaction_lock: nil}

      # (58, 50): still outside the [59..61, 49..51] rect.
      {:noreply, state} = PlayerSession.handle_info({:movement, :movement_tick}, state)
      refute_receive {:touched, TouchNpc}, 50
      refute MapSet.member?(state.game_state.inside_npc_areas, gid)

      # (59, 50): enters the rect -> fires.
      {:noreply, state} = PlayerSession.handle_info({:movement, :movement_tick}, state)
      assert_receive {:touched, TouchNpc}
      assert MapSet.member?(state.game_state.inside_npc_areas, gid)
      assert {_pid, ref, ^gid} = state.interaction_lock

      # The (dialog-less) interaction finishes immediately; clear the lock
      # exactly like the real session's :DOWN handler does.
      assert_receive {:DOWN, ^ref, :process, pid, reason}
      {:noreply, state} = PlayerSession.handle_info({:DOWN, ref, :process, pid, reason}, state)
      assert state.interaction_lock == nil

      # (60, 50) and (61, 50): still inside -> no re-fire.
      {:noreply, state} = PlayerSession.handle_info({:movement, :movement_tick}, state)
      refute_receive {:touched, TouchNpc}, 50

      {:noreply, state} = PlayerSession.handle_info({:movement, :movement_tick}, state)
      refute_receive {:touched, TouchNpc}, 50

      # (62, 50): leaves the rect -> cleared.
      {:noreply, state} = PlayerSession.handle_info({:movement, :movement_tick}, state)
      refute MapSet.member?(state.game_state.inside_npc_areas, gid)

      # (61, 50): re-enters -> fires again.
      {:noreply, state} = PlayerSession.handle_info({:movement, :movement_tick}, state)
      assert_receive {:touched, TouchNpc}
      assert MapSet.member?(state.game_state.inside_npc_areas, gid)
    end
  end

  describe "trigger area with no OnTouch label" do
    test "falls back to on_talk/1 (rAthena warper behavior)" do
      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:x, 69)
        |> Map.put(:y, 50)
        |> Map.put(:walk_path, [{70, 50}])
        |> Map.put(:movement_state, :moving)

      register_player(game_state)

      state = %{game_state: game_state, connection_pid: self(), interaction_lock: nil}

      {:noreply, ticked_state} = PlayerSession.handle_info({:movement, :movement_tick}, state)

      assert_receive {:talked, WarperNpc}
      gid = gid_for(WarperNpc)
      assert {_pid, _ref, ^gid} = ticked_state.interaction_lock
    end
  end

  describe "busy player" do
    test "skips the fire but still marks the area entered" do
      gid = gid_for(TouchNpc)
      fake_lock = {self(), make_ref(), 999}

      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:x, 57)
        |> Map.put(:y, 50)
        |> Map.put(:walk_path, [{58, 50}, {59, 50}])
        |> Map.put(:movement_state, :moving)

      register_player(game_state)

      state = %{game_state: game_state, connection_pid: self(), interaction_lock: fake_lock}

      {:noreply, state} = PlayerSession.handle_info({:movement, :movement_tick}, state)
      {:noreply, state} = PlayerSession.handle_info({:movement, :movement_tick}, state)

      refute_receive {:touched, TouchNpc}, 100
      assert MapSet.member?(state.game_state.inside_npc_areas, gid)
      assert state.interaction_lock == fake_lock
    end
  end

  describe "disabled NPC" do
    test "never fires and is never marked entered" do
      gid = gid_for(TouchNpc)
      NpcSession.set_enabled(gid, false)

      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:x, 57)
        |> Map.put(:y, 50)
        |> Map.put(:walk_path, [{58, 50}, {59, 50}])
        |> Map.put(:movement_state, :moving)

      register_player(game_state)

      state = %{game_state: game_state, connection_pid: self(), interaction_lock: nil}

      {:noreply, state} = PlayerSession.handle_info({:movement, :movement_tick}, state)
      {:noreply, state} = PlayerSession.handle_info({:movement, :movement_tick}, state)

      refute_receive {:touched, TouchNpc}, 100
      refute MapSet.member?(state.game_state.inside_npc_areas, gid)
      assert state.interaction_lock == nil
    end
  end

  describe "a cell that is both a warp trigger and a touch rect" do
    test "the warp wins; no touch fires and the area is not marked entered" do
      gid = gid_for(TouchNpc)

      warp =
        struct!(Warp,
          id: "test_warp_60_50",
          map: @map,
          to_map: "izlude",
          x: 60,
          y: 50,
          xs: 0,
          ys: 0,
          to_x: 150,
          to_y: 190,
          sprite: 45,
          name: "Izlude"
        )

      stub(Warps, :for_map, fn
        @map -> {:ok, [warp]}
        _ -> :error
      end)

      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:x, 59)
        |> Map.put(:y, 50)
        |> Map.put(:walk_path, [{60, 50}])
        |> Map.put(:movement_state, :moving)

      register_player(game_state)

      state = %{game_state: game_state, connection_pid: self(), interaction_lock: nil}

      {:noreply, ticked_state} = PlayerSession.handle_info({:movement, :movement_tick}, state)

      assert_received {:"$gen_cast", {:warp, "izlude", 150, 190}}
      refute_receive {:touched, TouchNpc}, 50
      refute_receive {:talked, TouchNpc}, 50
      refute MapSet.member?(ticked_state.game_state.inside_npc_areas, gid)
    end
  end

  describe "overlapping trigger rects" do
    test "both placements are entered once each; staying in the overlap fires nothing new" do
      gid_a = gid_for(OverlapNpcA)
      gid_b = gid_for(OverlapNpcB)

      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:x, 77)
        |> Map.put(:y, 50)
        |> Map.put(:walk_path, [{78, 50}, {79, 50}, {80, 50}, {81, 50}, {82, 50}])
        |> Map.put(:movement_state, :moving)

      register_player(game_state)

      state = %{game_state: game_state, connection_pid: self(), interaction_lock: nil}

      # (78, 50): enters A's rect [78..82] only -> fires A.
      {:noreply, state} = PlayerSession.handle_info({:movement, :movement_tick}, state)
      assert_receive {:touched, OverlapNpcA}
      refute_receive {:touched, OverlapNpcB}, 50
      assert MapSet.member?(state.game_state.inside_npc_areas, gid_a)
      refute MapSet.member?(state.game_state.inside_npc_areas, gid_b)
      assert {_pid, ref_a, ^gid_a} = state.interaction_lock

      # The (dialog-less) interaction finishes immediately; clear the lock
      # like the real session's :DOWN handler does, so B's own entry below
      # isn't busy-skipped by A's already-finished interaction.
      assert_receive {:DOWN, ^ref_a, :process, pid_a, reason_a}

      {:noreply, state} =
        PlayerSession.handle_info({:DOWN, ref_a, :process, pid_a, reason_a}, state)

      assert state.interaction_lock == nil

      # (79, 50): still only inside A -> no new fire.
      {:noreply, state} = PlayerSession.handle_info({:movement, :movement_tick}, state)
      refute_receive {:touched, OverlapNpcA}, 50
      refute_receive {:touched, OverlapNpcB}, 50

      # (80, 50): now also inside B's rect [80..84] -> fires B only.
      {:noreply, state} = PlayerSession.handle_info({:movement, :movement_tick}, state)
      assert_receive {:touched, OverlapNpcB}
      refute_receive {:touched, OverlapNpcA}, 50
      assert MapSet.member?(state.game_state.inside_npc_areas, gid_a)
      assert MapSet.member?(state.game_state.inside_npc_areas, gid_b)

      # (81, 50) and (82, 50): still inside the overlap of both -> nothing new.
      {:noreply, state} = PlayerSession.handle_info({:movement, :movement_tick}, state)
      refute_receive {:touched, OverlapNpcA}, 50
      refute_receive {:touched, OverlapNpcB}, 50

      {:noreply, _state} = PlayerSession.handle_info({:movement, :movement_tick}, state)
      refute_receive {:touched, OverlapNpcA}, 50
      refute_receive {:touched, OverlapNpcB}, 50
    end
  end

  describe "warp/map change" do
    test "clears inside_npc_areas" do
      game_state =
        character()
        |> PlayerState.new()
        |> Map.put(:inside_npc_areas, MapSet.new([1, 2, 3]))

      relocated = PlayerState.relocate(game_state, "izlude", 10, 10)

      assert relocated.inside_npc_areas == MapSet.new()
    end
  end

  defp gid_for(module) do
    {^module, placement} = Enum.find(NpcRegistry.entries(), fn {mod, _} -> mod == module end)
    NpcRegistry.entity_id(placement)
  end

  defp register_player(game_state) do
    UnitRegistry.register_unit(:player, @char_id, PlayerState, game_state, self())
    SpatialIndex.add_unit(:player, @char_id, game_state.x, game_state.y, @map)
    Movement.drain_dirty(@map)
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
end
