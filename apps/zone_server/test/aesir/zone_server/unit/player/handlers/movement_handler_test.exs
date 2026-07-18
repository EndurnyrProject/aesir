defmodule Aesir.ZoneServer.Unit.Player.Handlers.MovementHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.CastCancel
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.MoveStop
  alias Aesir.Net.SelfMove
  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Unit, as: SkillUnit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

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

    stub(MapCache, :get, fn "prontera" -> {:ok, %{width: 200, height: 200}} end)
    stub(Cell, :traversable?, fn "prontera", _x, _y -> true end)
    stub(Cell, :step_traversable?, fn "prontera", _from, _to -> true end)
    stub(Pathfinding, :find_path, fn _map, {50, 50}, {51, 50} -> {:ok, [{50, 50}, {51, 50}]} end)
    stub(SpatialIndex, :get_visible_players, fn _ -> [] end)
    stub(Broadcast, :to_player, fn _, _ -> :ok end)
    stub(Broadcast, :to_players, fn _, _, _ -> :ok end)
    stub(Broadcast, :to_in_range, fn _, _, _, _, _, _ -> :ok end)
    stub(Warps, :for_map, fn _ -> :error end)

    stub(StatusDisplay, :spawn_state, fn _type, _id ->
      %{body_state: 0, health_state: 0, effect_state: 0, virtue: 0}
    end)

    stub(StatusDisplay, :active_icons, fn _type, _id -> [] end)
    stub(Interpreter, :can_move?, fn _type, _id -> true end)
    stub(SkillUnit, :in_range, fn _map, _x, _y, _range -> [] end)
    stub(Storage, :get_groups_at_cell, fn _map, _x, _y -> [] end)
    stub(FieldSupport, :sources_for_unit, fn _type, _id -> [] end)

    stub(SkillUnitManager, :sync_view, fn _observer_id, _enter_ids, _leave_ids ->
      MapSet.new()
    end)

    :ok
  end

  describe "handle_request_move/4" do
    test "cancels an in-flight cast before starting to move" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1, packet -> send(test_pid, {:to_player, packet}) end)

      {:noreply, new_state} = MovementHandler.handle_request_move(casting_state(), 51, 50)

      assert new_state.game_state.movement_state == :moving
      assert_received {:to_player, %CastCancel{gid: 1}}
    end

    test "sends the mover a SelfMove on the gameplay channel" do
      {:noreply, new_state} = MovementHandler.handle_request_move(idle_state(), 51, 50)

      assert new_state.game_state.movement_state == :moving

      assert_received {:send, :gameplay,
                       {:self_move, %SelfMove{src_x: 50, src_y: 50, dst_x: 51, dst_y: 50}}}
    end

    test "walks the full per-cell path and delays the first tick by one step" do
      stub(Pathfinding, :find_path, fn _map, {50, 50}, {54, 50} ->
        {:ok, [{51, 50}, {52, 50}, {53, 50}, {54, 50}]}
      end)

      {:noreply, new_state} = MovementHandler.handle_request_move(idle_state(), 54, 50)

      # A collapsed straight segment would cross at many times walk speed; the
      # stepper must consume every cell, one step delay at a time.
      assert new_state.game_state.walk_path == [{51, 50}, {52, 50}, {53, 50}, {54, 50}]

      # The first tick lands after the first step's cost (150ms at base speed),
      # never immediately: stepping at schedule time would lead the client.
      refute_receive :movement_tick, 50
      assert_receive :movement_tick, 300
    end

    test "does not broadcast a movement UnitSpawn to nearby players" do
      # Movement now reaches observers via per-map delta snapshots
      # (see Map.CoordinatorFlushTest), not a reliable UnitSpawn{moving: true}.
      test_pid = self()
      stub(SpatialIndex, :get_visible_players, fn 1 -> [2] end)

      stub(Broadcast, :to_players, fn ids, packet, _opts ->
        send(test_pid, {:broadcast, ids, packet})
      end)

      {:noreply, _new_state} = MovementHandler.handle_request_move(idle_state(), 51, 50)

      refute_received {:broadcast, _ids, %UnitSpawn{}}
    end
  end

  describe "handle_request_move/4 status gating" do
    test "a player under a no_move status is snapped back and no path is set" do
      stub(Interpreter, :can_move?, fn :player, 1 -> false end)

      {:noreply, new_state} = MovementHandler.handle_request_move(idle_state(), 51, 50)

      assert new_state.game_state.movement_state == :standing
      assert new_state.game_state.walk_path == []
      assert_received {:send, :gameplay, {:move_stop, %MoveStop{gid: 1, x: 50, y: 50}}}
      refute_received {:send, :gameplay, {:self_move, %SelfMove{}}}
    end

    test "an unafflicted player moves exactly as before" do
      {:noreply, new_state} = MovementHandler.handle_request_move(idle_state(), 51, 50)

      assert new_state.game_state.movement_state == :moving
      assert_received {:send, :gameplay, {:self_move, %SelfMove{}}}
      refute_received {:send, :gameplay, {:move_stop, %MoveStop{}}}
    end
  end

  describe "handle_request_move/4 combat disengage" do
    test "a manual move cancels a locked auto-attack loop and clears the timer" do
      stub(Pathfinding, :find_path, fn _map, _from, _to ->
        {:ok, [{50, 50}, {55, 55}, {60, 60}]}
      end)

      ref = Process.send_after(self(), {:auto_attack, 2000}, 60_000)

      game_state =
        character()
        |> PlayerState.new()
        |> PlayerState.set_combat_intent(2000, 7, {60, 60})

      {:ok, attacking} = PlayerState.transition_to(game_state, :attacking)
      attacking = PlayerState.set_continuous_timer(attacking, ref)
      state = %{game_state: attacking, connection_pid: self()}

      {:noreply, new_state} = MovementHandler.handle_request_move(state, 60, 60)

      assert Process.read_timer(ref) == false
      assert new_state.game_state.continuous_attack_timer == nil
      assert new_state.game_state.combat_target_id == nil
      assert new_state.game_state.action_state == :moving
      refute_received {:auto_attack, _}
    end
  end

  describe "handle_movement_tick/1 status gating" do
    test "a moving player who becomes restricted stops and is snapped back" do
      stub(Interpreter, :can_move?, fn :player, 1 -> false end)

      {:noreply, new_state} = MovementHandler.handle_movement_tick(moving_state())

      assert new_state.game_state.movement_state == :standing
      assert new_state.game_state.walk_path == []
      assert_received {:send, :gameplay, {:move_stop, %MoveStop{gid: 1, x: 50, y: 50}}}
    end

    test "an unafflicted moving player is not stopped by the gate" do
      Mimic.copy(Movement)
      stub(Movement, :set_position, fn _type, _id, _state, _map -> :ok end)

      stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
      stub(SpatialIndex, :get_units_in_range, fn :mob, _, _, _, _ -> [] end)

      {:noreply, _new_state} = MovementHandler.handle_movement_tick(moving_state())

      refute_received {:send, :gameplay, {:move_stop, %MoveStop{}}}
    end

    test "makes no manager calls when the destination has no groups or support" do
      Mimic.copy(Movement)
      stub(Movement, :set_position, fn _type, _id, _state, _map -> :ok end)
      expect(Storage, :get_groups_at_cell, fn "prontera", 51, 50 -> [] end)
      expect(FieldSupport, :sources_for_unit, fn :player, 1 -> [] end)
      reject(&SkillUnitManager.reconcile_unit/1)
      reject(&SkillUnitManager.sync_view/3)

      {:noreply, _new_state} = MovementHandler.handle_movement_tick(moving_state())
    end

    test "reconciles support when leaving its group for an empty destination" do
      test_pid = self()
      Mimic.copy(Movement)
      stub(Movement, :set_position, fn _type, _id, _state, _map -> :ok end)
      expect(Storage, :get_groups_at_cell, fn "prontera", 51, 50 -> [] end)

      expect(FieldSupport, :sources_for_unit, fn :player, 1 ->
        [{:player, 1, :sc_quagmire, 77, []}]
      end)

      expect(SkillUnitManager, :reconcile_unit, fn {:player, 1} ->
        send(test_pid, :reconciled)
        :ok
      end)

      {:noreply, _new_state} = MovementHandler.handle_movement_tick(moving_state())

      assert_received :reconciled
    end

    test "reconciles field support when the destination has skill-unit groups" do
      test_pid = self()
      Mimic.copy(Movement)
      stub(Movement, :set_position, fn _type, _id, _state, _map -> :ok end)
      expect(Storage, :get_groups_at_cell, fn "prontera", 51, 50 -> [:group] end)

      expect(SkillUnitManager, :reconcile_unit, fn {:player, 1} ->
        send(test_pid, :reconciled)
        :ok
      end)

      {:noreply, _new_state} = MovementHandler.handle_movement_tick(moving_state())

      assert_received :reconciled
    end

    test "a dynamic movement blocker stops the player before it steps into the cell" do
      Mimic.copy(Movement)
      stub(Cell, :step_traversable?, fn "prontera", {50, 50}, {51, 50} -> false end)
      stub(Pathfinding, :find_path, fn _map, _from, _destination -> {:error, :no_path} end)
      stub(Movement, :set_position, fn _type, _id, _state, _map -> :ok end)

      {:noreply, new_state} = MovementHandler.handle_movement_tick(moving_state())

      assert {new_state.game_state.x, new_state.game_state.y} == {50, 50}
      assert new_state.game_state.movement_state == :standing
      assert_received {:send, :gameplay, {:move_stop, %MoveStop{gid: 1, x: 50, y: 50}}}
    end
  end

  describe "handle_message/2 inbound dispatch" do
    test "a MoveRequest drives handle_request_move with the same destination" do
      {:noreply, new_state} =
        PacketHandler.handle_message(%MoveRequest{dest_x: 51, dest_y: 50}, idle_state())

      assert new_state.game_state.movement_state == :moving
      assert List.last(new_state.game_state.walk_path) == {51, 50}

      assert_received {:send, :gameplay,
                       {:self_move, %SelfMove{src_x: 50, src_y: 50, dst_x: 51, dst_y: 50}}}
    end
  end

  describe "handle_visibility_update/1 mob lifecycle" do
    test "a newly-visible mob yields a UnitSpawn; a now-hidden mob yields a UnitDespawn" do
      test_pid = self()
      game_state = %{idle_state().game_state | visible_mobs: MapSet.new([99])}

      stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
      stub(SpatialIndex, :get_units_in_range, fn :mob, _, _, _, _ -> [42] end)
      stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)

      mob_state = %MobState{
        instance_id: 42,
        mob_id: 1002,
        mob_data: mob_definition(),
        spawn_ref: nil,
        map_name: "prontera",
        x: 51,
        y: 50,
        dir: 0,
        hp: 50,
        max_hp: 60,
        sp: 0,
        max_sp: 0,
        spawned_at: System.system_time(:second),
        walk_speed: 200,
        is_dead: false
      }

      # Both the mob spawn and the mob despawn target the same observing player
      # session. Forward every cast to the test process so we can assert both.
      observer_pid =
        spawn(fn -> forward_casts(test_pid) end)

      stub(UnitRegistry, :get_player_pid, fn 1 -> {:ok, observer_pid} end)

      stub(UnitRegistry, :get_unit, fn :mob, 42 ->
        {:ok, {MobSession, mob_state, observer_pid}}
      end)

      _ = MovementHandler.handle_visibility_update(game_state)

      assert_receive {:cast, %UnitSpawn{gid: 42, moving: false, name: "Poring"}}, 500
      assert_receive {:cast, %UnitDespawn{gid: 99, reason: 0}}, 500
    end

    test "a newly-visible mob's spawn carries its sprite-state aggregate" do
      test_pid = self()
      game_state = idle_state().game_state

      stub(StatusDisplay, :spawn_state, fn :mob, 42 ->
        %{body_state: 1, health_state: 4, effect_state: 0, virtue: 0}
      end)

      stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
      stub(SpatialIndex, :get_units_in_range, fn :mob, _, _, _, _ -> [42] end)
      stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)

      mob_state = mob_state(42)

      observer_pid = spawn(fn -> forward_casts(test_pid) end)
      stub(UnitRegistry, :get_player_pid, fn 1 -> {:ok, observer_pid} end)

      stub(UnitRegistry, :get_unit, fn :mob, 42 ->
        {:ok, {MobSession, mob_state, observer_pid}}
      end)

      _ = MovementHandler.handle_visibility_update(game_state)

      assert_receive {:cast,
                      %UnitSpawn{
                        gid: 42,
                        body_state: 1,
                        health_state: 4,
                        effect_state: 0,
                        virtue: 0
                      }},
                     500
    end

    test "a newly-visible mob follows its spawn with active icons to the observer" do
      test_pid = self()
      game_state = idle_state().game_state

      icon = %Aesir.Net.StatusChange{unit_id: 42, efst: 7, on: true}
      stub(StatusDisplay, :active_icons, fn :mob, 42 -> [icon] end)

      stub(Broadcast, :to_player, fn observer, packet ->
        send(test_pid, {:icon_to, observer, packet})
        :ok
      end)

      stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
      stub(SpatialIndex, :get_units_in_range, fn :mob, _, _, _, _ -> [42] end)
      stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)

      mob_state = mob_state(42)

      observer_pid = spawn(fn -> forward_casts(test_pid) end)
      stub(UnitRegistry, :get_player_pid, fn 1 -> {:ok, observer_pid} end)

      stub(UnitRegistry, :get_unit, fn :mob, 42 ->
        {:ok, {MobSession, mob_state, observer_pid}}
      end)

      _ = MovementHandler.handle_visibility_update(game_state)

      assert_receive {:icon_to, 1, ^icon}, 500
    end
  end

  describe "handle_visibility_update/1 warp lifecycle" do
    test "a newly-visible warp yields a UnitSpawn with object_type npc, sprite, x/y and name" do
      test_pid = self()
      game_state = %{idle_state().game_state | visible_warps: MapSet.new()}

      warp = %Warp{
        id: "prontera_izlude_gate",
        map: "prontera",
        to_map: "izlude",
        x: 60,
        y: 50,
        xs: 1,
        ys: 1,
        to_x: 150,
        to_y: 190,
        sprite: 45,
        name: "Izlude"
      }

      stub(Warps, :for_map, fn "prontera" -> {:ok, [warp]} end)
      stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
      stub(SpatialIndex, :get_units_in_range, fn :mob, _, _, _, _ -> [] end)
      stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)

      observer_pid = spawn(fn -> forward_casts(test_pid) end)
      stub(UnitRegistry, :get_player_pid, fn 1 -> {:ok, observer_pid} end)

      updated = MovementHandler.handle_visibility_update(game_state)

      assert_receive {:cast, %UnitSpawn{object_type: 0x1, job: 45, x: 60, y: 50, name: "Izlude"}},
                     500

      assert MapSet.member?(updated.visible_warps, Warp.Registry.entity_id(warp))
    end

    test "a now-hidden warp yields a UnitDespawn with reason out_of_sight" do
      test_pid = self()

      warp = %Warp{
        id: "prontera_izlude_gate",
        map: "prontera",
        to_map: "izlude",
        x: 60,
        y: 50,
        xs: 1,
        ys: 1,
        to_x: 150,
        to_y: 190,
        sprite: 45,
        name: "Izlude"
      }

      game_state = %{
        idle_state().game_state
        | visible_warps: MapSet.new([Warp.Registry.entity_id(warp)])
      }

      # Warp is now out of view range (player at 50,50; warp at 200,200 -> dist 300).
      far_warp = %{warp | x: 200, y: 200}
      stub(Warps, :for_map, fn "prontera" -> {:ok, [far_warp]} end)
      stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
      stub(SpatialIndex, :get_units_in_range, fn :mob, _, _, _, _ -> [] end)
      stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)

      observer_pid = spawn(fn -> forward_casts(test_pid) end)
      stub(UnitRegistry, :get_player_pid, fn 1 -> {:ok, observer_pid} end)

      updated = MovementHandler.handle_visibility_update(game_state)

      assert_receive {:cast, %UnitDespawn{gid: gid, reason: 0}}, 500
      assert gid == Warp.Registry.entity_id(warp)
      assert MapSet.size(updated.visible_warps) == 0
    end

    test "a warp staying in view across a tick does not get a duplicate spawn packet" do
      test_pid = self()
      warp = %Warp{id: "w", map: "prontera", to_map: "izlude", x: 60, y: 50, to_x: 0, to_y: 0}

      game_state = %{
        idle_state().game_state
        | visible_warps: MapSet.new([Warp.Registry.entity_id(warp)])
      }

      stub(Warps, :for_map, fn "prontera" -> {:ok, [warp]} end)
      stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
      stub(SpatialIndex, :get_units_in_range, fn :mob, _, _, _, _ -> [] end)
      stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)

      observer_pid = spawn(fn -> forward_casts(test_pid) end)
      stub(UnitRegistry, :get_player_pid, fn 1 -> {:ok, observer_pid} end)

      warp_gid = Warp.Registry.entity_id(warp)

      _updated = MovementHandler.handle_visibility_update(game_state)

      refute_received {:cast, %UnitSpawn{gid: ^warp_gid}}
      refute_received {:cast, %UnitDespawn{gid: ^warp_gid}}
    end

    test "two warps on the same map get distinct, stable gids that never collide" do
      test_pid = self()

      warp_a = %Warp{id: "a", map: "prontera", to_map: "izlude", x: 60, y: 50, to_x: 0, to_y: 0}
      warp_b = %Warp{id: "b", map: "prontera", to_map: "geffen", x: 55, y: 45, to_x: 0, to_y: 0}

      game_state = %{idle_state().game_state | visible_warps: MapSet.new()}

      stub(Warps, :for_map, fn "prontera" -> {:ok, [warp_a, warp_b]} end)
      stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
      stub(SpatialIndex, :get_units_in_range, fn :mob, _, _, _, _ -> [] end)
      stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)

      observer_pid = spawn(fn -> forward_casts(test_pid) end)
      stub(UnitRegistry, :get_player_pid, fn 1 -> {:ok, observer_pid} end)

      id_a = Warp.Registry.entity_id(warp_a)
      id_b = Warp.Registry.entity_id(warp_b)
      assert id_a != id_b

      _updated = MovementHandler.handle_visibility_update(game_state)

      gids =
        Enum.flat_map(1..2, fn _ ->
          receive do
            {:cast, %UnitSpawn{gid: gid}} -> [gid]
          after
            500 -> []
          end
        end)

      assert Enum.sort(gids) == Enum.sort([id_a, id_b])
    end
  end

  describe "handle_visibility_update/1 skill-unit lifecycle" do
    test "syncs all skill-unit visibility changes with one manager call" do
      test_pid = self()

      groups = [
        %Group{
          group_id: 77,
          skill_id: 12,
          skill_name: :wz_icewall,
          level: 1,
          caster_id: 2,
          caster_type: :player,
          map_name: "prontera",
          center: {50, 50},
          cells: [{50, 50}, {51, 50}, {52, 50}]
        },
        %Group{
          group_id: 78,
          skill_id: 12,
          skill_name: :wz_icewall,
          level: 1,
          caster_id: 2,
          caster_type: :player,
          map_name: "prontera",
          center: {50, 50},
          cells: [{50, 50}]
        }
      ]

      stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
      stub(SpatialIndex, :get_units_in_range, fn :mob, _, _, _, _ -> [] end)
      stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)

      stub(SkillUnit, :in_range, fn _map, x, _y, _range ->
        if x == 50, do: groups, else: []
      end)

      stub(SkillUnitManager, :sync_view, fn observer_id, enter_ids, leave_ids ->
        send(test_pid, {:sync_view, observer_id, enter_ids, leave_ids})
        MapSet.new(enter_ids -- leave_ids)
      end)

      entered = MovementHandler.handle_visibility_update(idle_state().game_state)
      assert_received {:sync_view, 1, [77, 78], []}
      assert entered.visible_skill_units == MapSet.new([77, 78])

      _still_visible = MovementHandler.handle_visibility_update(entered)
      refute_received {:sync_view, _, _, _}

      hidden =
        entered
        |> PlayerState.update_position(200, 50)
        |> MovementHandler.handle_visibility_update()

      assert_received {:sync_view, 1, [], [77, 78]}
      assert hidden.visible_skill_units == MapSet.new()

      reentered =
        hidden
        |> PlayerState.update_position(50, 50)
        |> MovementHandler.handle_visibility_update()

      assert_received {:sync_view, 1, [77, 78], []}
      assert reentered.visible_skill_units == MapSet.new([77, 78])
    end

    test "does not call the manager when the range diff is empty" do
      test_pid = self()

      stub(SkillUnitManager, :sync_view, fn _observer_id, _enter_ids, _leave_ids ->
        send(test_pid, :synced)
      end)

      updated = MovementHandler.handle_visibility_update(idle_state().game_state)

      assert updated.visible_skill_units == MapSet.new()
      refute_received :synced
    end

    test "keeps only manager-accepted groups when an entered group has expired" do
      group = %Group{
        group_id: 77,
        skill_id: 12,
        skill_name: :wz_icewall,
        level: 1,
        caster_id: 2,
        caster_type: :player,
        map_name: "prontera",
        center: {50, 50},
        cells: [{50, 50}]
      }

      stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
      stub(SpatialIndex, :get_units_in_range, fn :mob, _, _, _, _ -> [] end)
      stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)
      stub(SkillUnit, :in_range, fn _, _, _, _ -> [group] end)
      stub(SkillUnitManager, :sync_view, fn _observer_id, [77], [] -> MapSet.new() end)

      updated = MovementHandler.handle_visibility_update(idle_state().game_state)

      assert updated.visible_skill_units == MapSet.new()
    end
  end

  defp idle_state do
    %{game_state: PlayerState.new(character()), connection_pid: self()}
  end

  defp moving_state do
    game_state = PlayerState.set_path(PlayerState.new(character()), [{51, 50}])
    %{game_state: game_state, connection_pid: self()}
  end

  defp mob_state(instance_id) do
    %MobState{
      instance_id: instance_id,
      mob_id: 1002,
      mob_data: mob_definition(),
      spawn_ref: nil,
      map_name: "prontera",
      x: 51,
      y: 50,
      dir: 0,
      hp: 50,
      max_hp: 60,
      sp: 0,
      max_sp: 0,
      spawned_at: System.system_time(:second),
      walk_speed: 200,
      is_dead: false
    }
  end

  defp mob_definition do
    %MobDefinition{
      id: 1002,
      aegis_name: "PORING",
      name: "Poring",
      level: 3,
      hp: 60,
      sp: 0,
      atk: 7,
      matk: 0,
      def: 0,
      mdef: 5,
      stats: %{str: 1, agi: 1, vit: 1, int: 0, dex: 6, luk: 30},
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      element: {:water, 1},
      race: :plant,
      size: :medium,
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 672,
      client_attack_motion: 500,
      damage_motion: 480,
      ai_type: 0,
      modes: [],
      drops: []
    }
  end

  defp forward_casts(test_pid) do
    receive do
      {:"$gen_cast", {:send_packet, packet}} ->
        send(test_pid, {:cast, packet})
        forward_casts(test_pid)
    after
      1_000 -> :ok
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
