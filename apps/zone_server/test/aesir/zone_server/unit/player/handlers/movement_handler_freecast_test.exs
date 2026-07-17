defmodule Aesir.ZoneServer.Unit.Player.Handlers.MovementHandlerFreecastTest do
  @moduledoc """
  Free Cast (SA_FREECAST) as seen from the movement engine: a caster who knows it
  walks with the cast still in flight, at a walk-speed cost; a caster who does
  not is hard-cancelled exactly as before.

  `MovementHandlerTest`'s "cancels an in-flight cast before starting to move"
  pins the no-Free-Cast path from the other side.
  """
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.CastCancel
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Skill.Unit, as: SkillUnit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @freecast_id 278
  @storm_gust_id 89

  setup :set_mimic_from_context

  setup do
    Mimic.copy(MapCache)
    Mimic.copy(Cell)
    Mimic.copy(Pathfinding)
    Mimic.copy(SpatialIndex)
    Mimic.copy(Broadcast)
    Mimic.copy(UnitRegistry)
    Mimic.copy(Warps)
    Mimic.copy(StatusDisplay)
    Mimic.copy(Interpreter)
    Mimic.copy(SkillUnit)
    Mimic.copy(SkillUnitManager)
    Mimic.copy(Storage)
    Mimic.copy(FieldSupport)
    Mimic.copy(Movement)

    stub(MapCache, :get, fn "prontera" -> {:ok, %{width: 200, height: 200}} end)
    stub(Cell, :traversable?, fn "prontera", _x, _y -> true end)
    stub(Pathfinding, :find_path, fn _map, {50, 50}, {51, 50} -> {:ok, [{50, 50}, {51, 50}]} end)
    stub(Pathfinding, :simplify_path, fn path, _map -> path end)
    stub(SpatialIndex, :get_players_in_range, fn _map, _x, _y, _r -> [] end)
    stub(SpatialIndex, :get_units_in_range, fn _type, _map, _x, _y, _r -> [] end)
    stub(Broadcast, :to_player, fn _, _ -> :ok end)
    stub(Broadcast, :to_in_range, fn _, _, _, _, _, _ -> :ok end)
    stub(Warps, :for_map, fn _ -> :error end)
    stub(Interpreter, :can_move?, fn _type, _id -> true end)
    stub(SkillUnit, :in_range, fn _map, _x, _y, _range -> [] end)
    stub(Storage, :get_groups_at_cell, fn _map, _x, _y -> [] end)
    stub(FieldSupport, :sources_for_unit, fn _type, _id -> [] end)
    stub(Movement, :set_position, fn _type, _id, _state, _map -> :ok end)

    stub(SkillUnitManager, :sync_view, fn _observer_id, _enter_ids, _leave_ids ->
      MapSet.new()
    end)

    :ok
  end

  describe "a caster who knows Free Cast" do
    test "walks with the cast still in flight instead of cancelling it" do
      state = casting_state(freecast_level: 5)
      context = state.game_state.casting

      {:noreply, moved} = MovementHandler.handle_request_move(state, 51, 50)

      assert moved.game_state.action_state == :moving
      assert moved.game_state.movement_state == :moving
      assert moved.game_state.casting == context
    end

    test "gets no cast bar cancellation" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1, packet -> send(test_pid, {:to_player, packet}) end)

      {:noreply, _} =
        MovementHandler.handle_request_move(casting_state(freecast_level: 5), 51, 50)

      refute_received {:to_player, %CastCancel{}}
    end
  end

  describe "a caster who does not know Free Cast" do
    test "still hard-cancels the cast on move" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1, packet -> send(test_pid, {:to_player, packet}) end)

      state = casting_state(freecast_level: 0)

      {:noreply, moved} = MovementHandler.handle_request_move(state, 51, 50)

      assert moved.game_state.casting == nil
      assert moved.game_state.movement_state == :moving
      assert_received {:to_player, %CastCancel{gid: 1}}
    end
  end

  describe "step_delay/3 while a cast is in flight" do
    test "each step costs (175 - 5*lv) percent of its normal delay" do
      # walk_speed 150ms/cell, one straight step: 150 * 150/100 at Free Cast 5.
      game_state = walking_game_state(freecast_level: 5, walk_speed: 150)

      assert MovementHandler.step_delay(game_state, {50, 50}, {51, 50}) == 225
    end

    test "the penalty scales with the learned level" do
      game_state = walking_game_state(freecast_level: 10, walk_speed: 200)

      # 200 * 125/100
      assert MovementHandler.step_delay(game_state, {50, 50}, {51, 50}) == 250
    end

    test "it compounds with the diagonal movement cost rather than replacing it" do
      game_state = walking_game_state(freecast_level: 10, walk_speed: 200)

      # round(200 * 1.414) = 283, then * 125/100
      assert MovementHandler.step_delay(game_state, {50, 50}, {51, 51}) == 353
    end

    test "a walker with no cast in flight is not slowed" do
      game_state = walking_game_state(freecast_level: 5, walk_speed: 150, casting: nil)

      assert MovementHandler.step_delay(game_state, {50, 50}, {51, 50}) == 150
    end

    test "a cast in flight without Free Cast learned carries no penalty" do
      game_state = walking_game_state(freecast_level: 0, walk_speed: 150)

      assert MovementHandler.step_delay(game_state, {50, 50}, {51, 50}) == 150
    end
  end

  describe "no stat recalculation" do
    test "walking with a cast in flight never rewrites walk_speed" do
      state = casting_state(freecast_level: 5)

      {:noreply, moved} = MovementHandler.handle_request_move(state, 51, 50)

      assert moved.game_state.walk_speed == state.game_state.walk_speed
    end
  end

  # A player mid-path, with a cast overlaid unless told otherwise.
  defp walking_game_state(opts) do
    state = casting_state(opts)
    walk_speed = Keyword.fetch!(opts, :walk_speed)

    %{
      state.game_state
      | walk_speed: walk_speed,
        walk_path: [{51, 50}, {52, 50}],
        movement_state: :moving,
        action_state: :moving,
        casting: Keyword.get(opts, :casting, state.game_state.casting)
    }
  end

  defp casting_state(opts) do
    freecast_level = Keyword.fetch!(opts, :freecast_level)
    base = PlayerState.new(character())

    learned =
      if freecast_level > 0 do
        %{@storm_gust_id => 10, @freecast_id => freecast_level}
      else
        %{@storm_gust_id => 10}
      end

    stats =
      put_in(base.stats, [Access.key!(:progression), Access.key!(:learned_skills)], learned)

    token = make_ref()
    now = System.monotonic_time(:millisecond)
    timer_ref = Process.send_after(self(), {:cast_complete, token}, 60_000)

    context = %{
      skill_id: @storm_gust_id,
      skill_level: 10,
      target: {:ground, 60, 60},
      element: :water,
      started_at: now,
      fixed_until: now + 60_000,
      total_until: now + 60_000,
      timer_ref: timer_ref,
      token: token,
      interruptible: true,
      combat_target_id: nil
    }

    {:ok, casting} = PlayerState.transition_to(%{base | stats: stats}, :casting, context)

    %{game_state: casting, connection_pid: self()}
  end

  defp character do
    %Character{
      id: 1,
      account_id: 100,
      name: "FreeCaster",
      class: 0,
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
      base_level: 1,
      job_level: 1,
      zeny: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      hp: 40,
      max_hp: 40,
      sp: 40,
      max_sp: 40,
      status_point: 0,
      skill_point: 0
    }
  end
end
