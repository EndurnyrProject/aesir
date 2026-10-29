defmodule Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.MoveStop
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Id, as: SkillUnitId
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Inventory.Ammo
  alias Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @nv_basic_id 1

  setup :set_mimic_from_context

  setup do
    Mimic.copy(Interpreter)
    Mimic.copy(Ammo)
    Mimic.copy(SkillUnitManager)
    Mimic.copy(UnitRegistry)
    stub(Interpreter, :can_attack?, fn _type, _id -> true end)
    :ok
  end

  describe "handle_message/2 inbound ActionRequest dispatch" do
    test "an attack ActionRequest dispatches request_attack with the same target/action" do
      state = %{game_state: %PlayerState{character_id: 1000}}

      expect(CombatActionHandler, :handle_attack_request, fn st, 2000, 0 -> {:noreply, st} end)

      assert {:noreply, ^state} =
               PacketHandler.handle_message(%ActionRequest{target_id: 2000, action: 0}, state)
    end

    test "a continuous-attack ActionRequest dispatches request_attack with action 7" do
      state = %{game_state: %PlayerState{character_id: 1000}}

      expect(CombatActionHandler, :handle_attack_request, fn st, 2000, 7 -> {:noreply, st} end)

      assert {:noreply, ^state} =
               PacketHandler.handle_message(%ActionRequest{target_id: 2000, action: 7}, state)
    end

    test "a sit ActionRequest does not dispatch request_attack" do
      state = sit_state(%{@nv_basic_id => 9})

      reject(&CombatActionHandler.handle_attack_request/3)

      assert {:noreply, ^state} =
               PacketHandler.handle_message(%ActionRequest{target_id: 0, action: 2}, state)
    end

    test "a sit ActionRequest is blocked when NV_BASIC < 3" do
      state = sit_state(%{})

      reject(&CombatActionHandler.handle_attack_request/3)

      log =
        capture_log(fn ->
          assert {:noreply, ^state} =
                   PacketHandler.handle_message(%ActionRequest{target_id: 0, action: 2}, state)
        end)

      assert log =~ "NV_BASIC"
    end

    test "a sit ActionRequest is blocked at NV_BASIC level 2" do
      state = sit_state(%{@nv_basic_id => 2})

      log =
        capture_log(fn ->
          assert {:noreply, ^state} =
                   PacketHandler.handle_message(%ActionRequest{target_id: 0, action: 2}, state)
        end)

      assert log =~ "NV_BASIC"
    end

    test "a stand ActionRequest passes when NV_BASIC >= 3" do
      state = sit_state(%{@nv_basic_id => 3})

      reject(&CombatActionHandler.handle_attack_request/3)

      assert {:noreply, ^state} =
               PacketHandler.handle_message(%ActionRequest{target_id: 0, action: 3}, state)
    end
  end

  defp sit_state(learned_skills) do
    progression = %PlayerProgression{learned_skills: learned_skills}

    %{
      game_state: %PlayerState{
        character_id: 1000,
        stats: %Stats{progression: progression}
      }
    }
  end

  describe "handle_stop_attack/1" do
    test "an attacking player drops its target and pending swing and goes idle" do
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      timer = Process.send_after(self(), :swing, 60_000)

      state = %{
        game_state: %PlayerState{
          character_id: 1000,
          action_state: :attacking,
          combat_target_id: 5,
          continuous_attack_timer: timer
        }
      }

      assert {:noreply, %{game_state: stopped}} = CombatActionHandler.handle_stop_attack(state)
      assert stopped.combat_target_id == nil
      assert stopped.continuous_attack_timer == nil
      assert stopped.action_state == :idle
      assert Process.read_timer(timer) == false
    end

    test "an idle player's resumed swing is dropped too" do
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      timer = Process.send_after(self(), :swing, 60_000)

      state = %{
        game_state: %PlayerState{
          character_id: 1000,
          action_state: :idle,
          combat_target_id: 5,
          continuous_attack_timer: timer
        }
      }

      assert {:noreply, %{game_state: stopped}} = CombatActionHandler.handle_stop_attack(state)
      assert stopped.combat_target_id == nil
      assert Process.read_timer(timer) == false
    end

    test "a walk into skill range keeps its pending skill" do
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)

      state = %{
        game_state: %PlayerState{
          character_id: 1000,
          action_state: :skill_moving,
          movement_state: :moving,
          movement_intent: :skill,
          state_context: %{skill_id: 13}
        }
      }

      assert {:noreply, %{game_state: walking}} = CombatActionHandler.handle_stop_attack(state)
      assert walking.action_state == :skill_moving
      assert walking.movement_intent == :skill
      assert walking.state_context == %{skill_id: 13}
    end

    test "a chase toward a target to attack is left alone" do
      state = %{
        game_state: %PlayerState{
          character_id: 1000,
          action_state: :combat_moving,
          movement_state: :moving,
          combat_target_id: 5
        }
      }

      assert {:noreply, ^state} = CombatActionHandler.handle_stop_attack(state)
    end
  end

  describe "after-cast act delay gate" do
    defp attack_ready_state(act_delay_until) do
      game_state = %PlayerState{
        character_id: 1000,
        x: 10,
        y: 10,
        action_state: :idle,
        last_attack_timestamp: 0,
        act_delay_until: act_delay_until,
        stats: %{derived_stats: %{aspd: 150}, equipment: %Equipment{}}
      }

      %{game_state: game_state}
    end

    test "a melee attack is blocked (no range check) while act-delayed" do
      future = System.monotonic_time(:millisecond) + 60_000
      state = attack_ready_state(future)

      log =
        capture_log(fn ->
          assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 0)
          assert returned.game_state.action_state == :idle
          send(self(), :done)
        end)

      assert_received :done
      refute log =~ "range"
    end

    test "a melee attack proceeds to the range check once the act delay is clear" do
      state = attack_ready_state(0)

      log =
        capture_log(fn ->
          assert {:noreply, _returned} = CombatActionHandler.handle_attack_request(state, 2000, 0)
          send(self(), :done)
        end)

      assert_received :done
      assert log =~ "range"
    end
  end

  describe "handle_attack_request/3 status gating" do
    defp restricted_state(action_state) do
      game_state = %PlayerState{
        character_id: 1000,
        x: 10,
        y: 10,
        action_state: action_state,
        last_attack_timestamp: 0,
        act_delay_until: 0,
        stats: %{derived_stats: %{aspd: 150}, equipment: %Equipment{}}
      }

      %{game_state: game_state, connection_pid: self()}
    end

    test "a no_attack player making a discrete swing does not attack nor enter :attacking" do
      stub(Interpreter, :can_attack?, fn :player, 1000 -> false end)
      state = restricted_state(:idle)

      assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 0)

      assert returned.game_state.action_state == :idle
      refute_received {:send, :gameplay, {:move_stop, %MoveStop{}}}
    end

    test "a no_attack player approaching a target is halted with a MoveStop and dropped to idle" do
      stub(Interpreter, :can_attack?, fn :player, 1000 -> false end)
      state = restricted_state(:combat_moving)

      assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 7)

      assert returned.game_state.action_state == :idle
      assert returned.game_state.combat_target_id == nil
      assert_received {:send, :gameplay, {:move_stop, %MoveStop{gid: 1000, x: 10, y: 10}}}
    end

    test "an unafflicted player proceeds to the range check as before" do
      state = restricted_state(:idle)

      log =
        capture_log(fn ->
          assert {:noreply, _returned} = CombatActionHandler.handle_attack_request(state, 2000, 0)
          send(self(), :done)
        end)

      assert_received :done
      assert log =~ "range"
      refute_received {:send, :gameplay, {:move_stop, %MoveStop{}}}
    end
  end

  describe "target acquisition gate" do
    defp acquire_state(map_name) do
      game_state = %PlayerState{
        character_id: 1000,
        x: 10,
        y: 10,
        map_name: map_name,
        action_state: :idle,
        last_attack_timestamp: 0,
        act_delay_until: 0,
        stats: %{derived_stats: %{aspd: 150}, equipment: %Equipment{}}
      }

      %{game_state: game_state, connection_pid: self()}
    end

    test "an attack on a target on a different map is rejected without attacking or chasing" do
      reject(&Combat.execute_attack/4)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {12, 12, "geffen"}}
      end)

      state = acquire_state("prontera")

      capture_log(fn ->
        assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 7)
        assert returned.game_state.action_state == :idle
        send(self(), :done)
      end)

      assert_received :done
      refute_received {:send, :gameplay, {:move_stop, _}}
    end

    test "an attack on a target beyond view range is rejected without attacking or chasing" do
      reject(&Combat.execute_attack/4)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {100, 100, "prontera"}}
      end)

      state = acquire_state("prontera")

      capture_log(fn ->
        assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 7)
        assert returned.game_state.action_state == :idle
        send(self(), :done)
      end)

      assert_received :done
      refute_received {:send, :gameplay, {:move_stop, _}}
    end
  end

  describe "combat target resolution" do
    test "resolves player targets before colliding mob IDs" do
      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:ok, {10, 11, "prontera"}}
        :mob, 2000 -> {:ok, {50, 50, "geffen"}}
      end)

      assert {:ok, :player, {10, 11, "prontera"}} = Combat.resolve_target_position(2000)
    end

    test "resolves mob targets when no player has the target ID" do
      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {10, 11, "prontera"}}
      end)

      assert {:ok, :mob, {10, 11, "prontera"}} = Combat.resolve_target_position(2000)
    end

    test "resolves targetable skill-unit targets" do
      target_id = SkillUnitId.first()

      stub(UnitRegistry, :get_unit, fn :skill_unit, ^target_id ->
        {:ok, {nil, nil, self()}}
      end)

      stub(SkillUnitManager, :targetable_cell, fn manager_pid, ^target_id
                                                  when manager_pid == self() ->
        {:ok, :cell}
      end)

      stub(SpatialIndex, :get_unit_position, fn :skill_unit, ^target_id ->
        {:ok, {10, 11, "prontera"}}
      end)

      assert {:ok, :skill_unit, {10, 11, "prontera"}} =
               Combat.resolve_target_position(target_id)
    end

    test "rejects stale skill-unit targets" do
      target_id = SkillUnitId.first()

      stub(UnitRegistry, :get_unit, fn :skill_unit, ^target_id -> {:error, :not_found} end)

      assert {:error, :target_not_found} = Combat.resolve_target_position(target_id)
    end

    test "rejects non-targetable skill-unit targets" do
      target_id = SkillUnitId.first()

      stub(UnitRegistry, :get_unit, fn :skill_unit, ^target_id ->
        {:ok, {nil, nil, self()}}
      end)

      stub(SkillUnitManager, :targetable_cell, fn manager_pid, ^target_id
                                                  when manager_pid == self() ->
        {:error, :not_targetable}
      end)

      assert {:error, :target_not_found} = Combat.resolve_target_position(target_id)
    end

    test "rejects skill-unit targets missing from the spatial index" do
      target_id = SkillUnitId.first()

      stub(UnitRegistry, :get_unit, fn :skill_unit, ^target_id ->
        {:ok, {nil, nil, self()}}
      end)

      stub(SkillUnitManager, :targetable_cell, fn manager_pid, ^target_id
                                                  when manager_pid == self() ->
        {:ok, :cell}
      end)

      stub(SpatialIndex, :get_unit_position, fn :skill_unit, ^target_id ->
        {:error, :not_found}
      end)

      assert {:error, :target_not_found} = Combat.resolve_target_position(target_id)
    end

    test "the attack handler preserves in-range attacks for every target type" do
      skill_unit_id = SkillUnitId.first()

      stub(UnitRegistry, :get_unit, fn :skill_unit, ^skill_unit_id ->
        {:ok, {nil, nil, self()}}
      end)

      stub(SkillUnitManager, :targetable_cell, fn manager_pid, ^skill_unit_id
                                                  when manager_pid == self() ->
        {:ok, :cell}
      end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:ok, {10, 11, "prontera"}}
        :player, 2001 -> {:error, :not_found}
        :mob, 2001 -> {:ok, {10, 11, "prontera"}}
        :skill_unit, ^skill_unit_id -> {:ok, {10, 11, "prontera"}}
      end)

      stub(Combat, :execute_attack, fn _stats, game_state, target_id, _recalculate ->
        send(self(), {:attacked, target_id})
        {:ok, game_state}
      end)

      state = acquire_state("prontera")

      for target_id <- [2000, 2001, skill_unit_id] do
        assert {:noreply, returned} =
                 CombatActionHandler.handle_attack_request(state, target_id, 0)

        assert returned.game_state.action_state == :idle
        assert_received {:attacked, ^target_id}
      end
    end
  end

  describe "get_optimal_attack_position/3" do
    test "returns current position when already in range" do
      attacker_pos = {100, 100}
      target_pos = {101, 101}
      weapon_range = 2

      result =
        CombatActionHandler.get_optimal_attack_position(
          attacker_pos,
          target_pos,
          weapon_range
        )

      assert result == {100, 100}
    end

    test "calculates position for melee range (1 cell)" do
      attacker_pos = {100, 100}
      target_pos = {105, 105}
      weapon_range = 1

      {optimal_x, optimal_y} =
        CombatActionHandler.get_optimal_attack_position(
          attacker_pos,
          target_pos,
          weapon_range
        )

      # Should move to within 1 cell of target
      distance = max(abs(optimal_x - 105), abs(optimal_y - 105))
      assert distance <= 1
    end

    test "calculates position for spear range (2 cells)" do
      attacker_pos = {100, 100}
      target_pos = {110, 110}
      weapon_range = 2

      {optimal_x, optimal_y} =
        CombatActionHandler.get_optimal_attack_position(
          attacker_pos,
          target_pos,
          weapon_range
        )

      # Should move to within 2 cells of target
      distance = max(abs(optimal_x - 110), abs(optimal_y - 110))
      assert distance <= 2
    end

    test "calculates position for ranged weapon (9 cells)" do
      attacker_pos = {100, 100}
      target_pos = {120, 120}
      weapon_range = 9

      {optimal_x, optimal_y} =
        CombatActionHandler.get_optimal_attack_position(
          attacker_pos,
          target_pos,
          weapon_range
        )

      # Should move to within 9 cells of target
      distance = max(abs(optimal_x - 120), abs(optimal_y - 120))
      assert distance <= 9
    end

    test "handles horizontal movement" do
      attacker_pos = {100, 100}
      target_pos = {110, 100}
      weapon_range = 1

      {optimal_x, optimal_y} =
        CombatActionHandler.get_optimal_attack_position(
          attacker_pos,
          target_pos,
          weapon_range
        )

      # Should move horizontally to within 1 cell
      assert optimal_y == 100
      assert abs(optimal_x - 110) <= 1
    end

    test "handles vertical movement" do
      attacker_pos = {100, 100}
      target_pos = {100, 110}
      weapon_range = 1

      {optimal_x, optimal_y} =
        CombatActionHandler.get_optimal_attack_position(
          attacker_pos,
          target_pos,
          weapon_range
        )

      # Should move vertically to within 1 cell
      assert optimal_x == 100
      assert abs(optimal_y - 110) <= 1
    end

    test "handles same position edge case" do
      attacker_pos = {100, 100}
      target_pos = {100, 100}
      weapon_range = 1

      result =
        CombatActionHandler.get_optimal_attack_position(
          attacker_pos,
          target_pos,
          weapon_range
        )

      assert result == {100, 100}
    end
  end

  describe "bow basic-attack ammo gate and consumption" do
    @ammo_bit EquipLocation.location_bit(:ammo)

    defp combat_state(inventory) do
      game_state = %PlayerState{
        character_id: 1000,
        x: 10,
        y: 10,
        map_name: "prontera",
        action_state: :idle,
        last_attack_timestamp: 0,
        act_delay_until: 0,
        combat_action_type: 0,
        inventory: inventory,
        stats: %{derived_stats: %{aspd: 150}, equipment: %Equipment{}}
      }

      %{game_state: game_state, connection_pid: self()}
    end

    defp stub_target_in_range do
      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {10, 11, "prontera"}}
      end)
    end

    test "a bow attack with no arrows fails with :no_ammo and never strikes" do
      stub(Stats, :weapon_type, fn _equipment -> :bow end)
      stub_target_in_range()
      reject(&Combat.execute_attack/4)

      state = combat_state(%{})

      log =
        capture_log(fn ->
          assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 0)
          assert returned.game_state.action_state == :idle
          send(self(), :done)
        end)

      assert_received :done
      assert log =~ "no_ammo"
      refute_received {:send, :gameplay, {:item_removed, _}}
    end

    test "a bow attack decrementing a stack strikes, consumes one, persists, syncs without recalc" do
      stub(Stats, :weapon_type, fn _equipment -> :bow end)

      stub(Calculator, :calculate_stats, fn _stats, _id, _equipped ->
        send(self(), :stats_recalced)
        :recalced
      end)

      stub_target_in_range()

      stub(Combat, :execute_attack, fn _stats, game_state, _target, _recalculate ->
        {:ok, game_state}
      end)

      stub(InventoryOps, :apply_change, fn _char, _old, new, _change ->
        send(self(), :persisted)
        {:ok, new}
      end)

      arrow = %InventoryItem{nameid: 1750, amount: 10, equip: @ammo_bit}
      state = combat_state(%{0 => arrow})

      capture_log(fn ->
        assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 0)
        assert %{0 => %InventoryItem{amount: 9}} = returned.game_state.inventory
        assert returned.game_state.stats == state.game_state.stats
        send(self(), :done)
      end)

      assert_received :done
      assert_received :persisted
      assert_received {:send, :gameplay, {:item_removed, %ItemRemoved{amount: 1}}}
      refute_received :stats_recalced
    end

    test "a stale target failure does not consume ammo, set cooldown, or arm auto-attack" do
      stub(Stats, :weapon_type, fn _equipment -> :bow end)
      stub_target_in_range()

      stub(Combat, :execute_attack, fn _stats, game_state, 2000, _recalculate ->
        {{:error, :target_not_found}, game_state}
      end)

      reject(&Ammo.consume_one/1)
      reject(&InventoryOps.apply_change/4)

      arrow = %InventoryItem{nameid: 1750, amount: 1, equip: @ammo_bit}
      state = combat_state(%{0 => arrow})
      state = %{state | game_state: %{state.game_state | combat_action_type: 7}}

      capture_log(fn ->
        assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 7)
        assert returned.game_state.inventory == state.game_state.inventory
        assert returned.game_state.last_attack_timestamp == 0
        assert returned.game_state.continuous_attack_timer == nil
        assert returned.game_state.combat_target_id == nil
      end)
    end

    test "a bow attack consuming the last arrow recalcs stats and clears the slot" do
      stub(Stats, :weapon_type, fn _equipment -> :bow end)

      stub(Calculator, :calculate_stats, fn _stats, _id, _equipped ->
        send(self(), :stats_recalced)
        :recalced
      end)

      stub_target_in_range()

      stub(Combat, :execute_attack, fn _stats, game_state, _target, _recalculate ->
        {:ok, game_state}
      end)

      stub(InventoryOps, :apply_change, fn _char, _old, new, _change ->
        send(self(), :persisted)
        {:ok, new}
      end)

      arrow = %InventoryItem{nameid: 1750, amount: 1, equip: @ammo_bit}
      state = combat_state(%{0 => arrow})

      capture_log(fn ->
        assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 0)
        refute Map.has_key?(returned.game_state.inventory, 0)
        assert returned.game_state.stats == :recalced
        send(self(), :done)
      end)

      assert_received :done
      assert_received :persisted
      assert_received :stats_recalced
      assert_received {:send, :gameplay, {:item_removed, %ItemRemoved{amount: 1}}}
    end

    test "a dagger attack strikes without consuming ammo" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)
      stub_target_in_range()

      stub(Combat, :execute_attack, fn _stats, game_state, _target, _recalculate ->
        {:ok, game_state}
      end)

      reject(&Ammo.consume_one/1)

      state = combat_state(%{})

      capture_log(fn ->
        assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 0)
        assert returned.game_state.action_state == :idle
        send(self(), :done)
      end)

      assert_received :done
      refute_received {:send, :gameplay, {:item_removed, _}}
    end
  end

  describe "attack and parry delays" do
    # ASPD 150: a 1000 ms attack delay and a 500 ms attack motion; a job held
    # at 190 ASPD adds 100 ms to the skill delay.
    test "a swing keeps the player from skills for its attack motion plus 100 ms" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)
      stub_target_in_range()

      stub(Combat, :execute_attack, fn _stats, game_state, _target, _recalculate ->
        {:ok, game_state}
      end)

      before = AttackSpeed.current_timestamp()

      capture_log(fn ->
        {:noreply, returned} =
          CombatActionHandler.handle_attack_request(combat_state(%{}), 2000, 0)

        send(self(), {:returned, returned})
      end)

      after_call = AttackSpeed.current_timestamp()
      assert_received {:returned, %{game_state: game_state}}
      assert game_state.act_delay_until in (before + 600)..(after_call + 600)
    end

    test "a parry makes the next attack wait a full attack delay and skills 600 ms" do
      before = AttackSpeed.current_timestamp()
      {:noreply, %{game_state: parried}} = CombatActionHandler.handle_parry(combat_state(%{}))
      after_call = AttackSpeed.current_timestamp()

      assert parried.last_attack_timestamp in before..after_call
      assert parried.act_delay_until in (before + 600)..(after_call + 600)
      refute AttackSpeed.can_attack?(parried.last_attack_timestamp, 1_000)
    end
  end

  describe "continuous auto-attack loop" do
    alias Aesir.ZoneServer.Map.MapCache
    alias Aesir.ZoneServer.Pathfinding
    alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler

    # ASPD 193 -> 70ms delay, so the rescheduled swing arrives promptly in tests.
    defp loop_state do
      game_state = %PlayerState{
        character_id: 1000,
        x: 10,
        y: 10,
        map_name: "prontera",
        action_state: :idle,
        last_attack_timestamp: 0,
        act_delay_until: 0,
        combat_action_type: 7,
        stats: %{derived_stats: %{aspd: 193}, equipment: %Equipment{}}
      }

      %{game_state: game_state, connection_pid: self()}
    end

    defp locked_state(extra) do
      game_state = Map.merge(loop_state().game_state, Map.new(extra))
      %{game_state: game_state, connection_pid: self()}
    end

    test "an intercepted swing deals no damage and continues the attack cadence" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {10, 11, "prontera"}}
      end)

      stub(Combat, :execute_attack, fn _stats, game_state, 2000, _recalculate ->
        send(self(), :attacked)
        {:intercepted, game_state}
      end)

      {:noreply, s1} = CombatActionHandler.handle_attack_request(loop_state(), 2000, 7)

      assert_received :attacked
      assert s1.game_state.combat_target_id == 2000
      assert s1.game_state.combo.stage == :idle
      assert is_reference(s1.game_state.continuous_attack_timer)
      assert_receive {:combat, {:auto_attack, 2000}}, 500
    end

    test "a continuous attack swings, locks the target and reschedules on the tick" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {10, 11, "prontera"}}
      end)

      stub(Combat, :execute_attack, fn _stats, game_state, 2000, _recalculate ->
        send(self(), :attacked)
        {:ok, game_state}
      end)

      {:noreply, s1} = CombatActionHandler.handle_attack_request(loop_state(), 2000, 7)

      assert_received :attacked
      assert s1.game_state.combat_target_id == 2000
      assert is_reference(s1.game_state.continuous_attack_timer)

      assert_receive {:combat, {:auto_attack, 2000}}, 500

      {:noreply, s2} = CombatActionHandler.handle_auto_attack(s1, 2000)

      assert_received :attacked
      assert is_reference(s2.game_state.continuous_attack_timer)
      assert_receive {:combat, {:auto_attack, 2000}}, 500
    end

    test "a Trifecta replacement opens and expires its window" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {10, 11, "prontera"}}
      end)

      stub(Combat, :execute_attack, fn _stats, game_state, 2000, _recalculate ->
        {{:ok, {:combo, :quadruple, 20}}, game_state}
      end)

      state = loop_state()
      stats = Map.put(state.game_state.stats, :progression, %{learned_skills: %{272 => 1}})
      state = put_in(state.game_state.stats, stats)

      {:noreply, opened} = CombatActionHandler.handle_attack_request(state, 2000, 7)

      assert %Combo{stage: :quadruple} = opened.game_state.combo
      generation = opened.game_state.combo.generation

      # At 193 ASPD the 70 ms attack motion outlasts the 20 ms delay: 70 + 300.
      refute_receive {:combo_timeout, ^generation}, 300
      assert_receive {:combo_timeout, ^generation}, 500
      assert {:noreply, expired} = CombatActionHandler.handle_combo_timeout(opened, generation)
      assert expired.game_state.combo.stage == :idle
    end

    test "walking, swinging and warping keep an open combo window, which dies with its owner" do
      combo = Combo.open(Combo.new(), :quadruple, 9_999_999_999)
      state = loop_state()
      game_state = %{state.game_state | combo: combo}

      assert {:ok, moving} = PlayerState.transition_to(game_state, :moving)
      assert moving.combo.stage == :quadruple

      assert {:ok, attacking} =
               PlayerState.transition_to(%{game_state | action_state: :idle}, :attacking)

      assert attacking.combo.stage == :quadruple

      assert {:ok, dead} =
               PlayerState.transition_to(%{game_state | action_state: :idle}, :dead)

      assert dead.combo.stage == :quadruple

      warped = PlayerState.relocate(game_state, "morocc", 10, 10)
      assert warped.combo.stage == :quadruple
    end

    test "a swing keeps the open combo window" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {10, 11, "prontera"}}
      end)

      stub(Combat, :execute_attack, fn _stats, game_state, 2000, _recalculate ->
        send(self(), :attacked)
        {:ok, game_state}
      end)

      combo = Combo.open(Combo.new(), :quadruple, 9_999_999_999)
      state = loop_state()
      state = %{state | game_state: %{state.game_state | combo: combo, combat_target_id: 2000}}

      assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 7)

      assert_received :attacked
      assert returned.game_state.combo.stage == :quadruple
    end

    test "a dead or missing target stops the loop and clears combat intent" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)
      stub(SpatialIndex, :get_unit_position, fn _type, _id -> {:error, :not_found} end)
      reject(&Combat.execute_attack/4)

      ref = Process.send_after(self(), :never, 60_000)
      state = locked_state(%{combat_target_id: 2000, continuous_attack_timer: ref})

      {:noreply, returned} = CombatActionHandler.handle_auto_attack(state, 2000)

      assert returned.game_state.combat_target_id == nil
      assert returned.game_state.continuous_attack_timer == nil
      assert Process.read_timer(ref) == false
      refute_received {:combat, {:auto_attack, _}}
    end

    test "a stunned player stops the loop instead of swinging through" do
      stub(Interpreter, :can_attack?, fn :player, 1000 -> false end)
      reject(&Combat.execute_attack/4)

      ref = Process.send_after(self(), :never, 60_000)
      state = locked_state(%{combat_target_id: 2000, continuous_attack_timer: ref})

      {:noreply, returned} = CombatActionHandler.handle_auto_attack(state, 2000)

      assert returned.game_state.combat_target_id == nil
      assert Process.read_timer(ref) == false
      refute_received {:combat, {:auto_attack, _}}
    end

    test "an auto-attack for a target that is no longer locked is ignored" do
      reject(&Combat.execute_attack/4)
      state = locked_state(%{combat_target_id: 9999})

      assert {:noreply, ^state} = CombatActionHandler.handle_auto_attack(state, 2000)
    end

    test "an out-of-range target triggers re-approach and keeps the loop alive" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {30, 30, "prontera"}}
      end)

      reject(&Combat.execute_attack/4)
      Mimic.copy(Aesir.ZoneServer.Map.Cell)
      stub(Aesir.ZoneServer.Map.Cell, :traversable?, fn "prontera", _x, _y -> true end)
      stub(MapCache, :get, fn "prontera" -> {:ok, :map_data} end)
      stub(Pathfinding, :rewalk_path, fn _map, _from, _to -> {:ok, [{29, 29}]} end)

      stub(MovementHandler, :handle_request_move, fn s, _x, _y, _opts ->
        send(self(), :move_requested)
        {:noreply, s}
      end)

      state = locked_state(%{combat_target_id: 2000})

      {:noreply, returned} = CombatActionHandler.handle_auto_attack(state, 2000)

      assert_received :move_requested
      assert returned.game_state.action_state == :combat_moving
      assert returned.game_state.combat_target_id == 2000
    end

    test "an early tick is absorbed by the ASPD gate instead of double-swinging" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {10, 11, "prontera"}}
      end)

      # Any swing here would violate the ASPD cadence: the last one just landed.
      reject(&Combat.execute_attack/4)

      old_ref = Process.send_after(self(), :never, 60_000)

      state =
        locked_state(%{
          combat_target_id: 2000,
          action_state: :attacking,
          last_attack_timestamp: System.monotonic_time(:millisecond),
          continuous_attack_timer: old_ref
        })

      {:noreply, returned} = CombatActionHandler.handle_auto_attack(state, 2000)

      # No extra swing and no double-armed timer: the old one is replaced by a reschedule.
      assert Process.read_timer(old_ref) == false
      assert is_reference(returned.game_state.continuous_attack_timer)
      assert returned.game_state.continuous_attack_timer != old_ref
      assert returned.game_state.action_state == :attacking
      assert_receive {:combat, {:auto_attack, 2000}}, 500
    end
  end

  describe "logout window" do
    setup do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {10, 11, "prontera"}}
      end)

      :ok
    end

    test "a swing and an in-range wait for the attack delay open it" do
      stub(Combat, :execute_attack, fn _stats, game_state, 2000, _recalculate ->
        {:ok, game_state}
      end)

      {:noreply, swung} = CombatActionHandler.handle_attack_request(loop_state(), 2000, 7)

      assert is_integer(swung.canlog_at)

      waiting =
        locked_state(%{
          combat_target_id: 2000,
          action_state: :attacking,
          last_attack_timestamp: System.monotonic_time(:millisecond)
        })

      {:noreply, waited} = CombatActionHandler.handle_auto_attack(waiting, 2000)

      assert is_integer(waited.canlog_at)
    end

    test "a swing that never reached its target leaves it closed" do
      stub(Combat, :execute_attack, fn _stats, game_state, 2000, _recalculate ->
        {{:error, :target_not_found}, game_state}
      end)

      capture_log(fn ->
        {:noreply, returned} = CombatActionHandler.handle_attack_request(loop_state(), 2000, 7)
        send(self(), {:returned, returned})
      end)

      assert_received {:returned, returned}
      assert Map.get(returned, :canlog_at) == nil
    end
  end

  describe "move-to-attack adjacency without cell reservations" do
    alias Aesir.ZoneServer.Map.Cell
    alias Aesir.ZoneServer.Map.MapCache
    alias Aesir.ZoneServer.Pathfinding
    alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler

    defp approach_state(extra \\ %{}) do
      game_state =
        %PlayerState{
          character_id: 1000,
          x: 10,
          y: 10,
          map_name: "prontera",
          action_state: :idle,
          last_attack_timestamp: 0,
          act_delay_until: 0,
          combat_action_type: 7,
          stats: %{derived_stats: %{aspd: 150}, equipment: %Equipment{}}
        }
        |> Map.merge(Map.new(extra))

      %{game_state: game_state, connection_pid: self()}
    end

    defp stub_open_terrain do
      Mimic.copy(Cell)
      stub(MapCache, :get, fn "prontera" -> {:ok, :map_data} end)
      stub(Cell, :traversable?, fn "prontera", _x, _y -> true end)
      stub(Pathfinding, :rewalk_path, fn _map, _from, to -> {:ok, [to]} end)
    end

    defp capture_moves(tag) do
      stub(MovementHandler, :handle_request_move, fn s, x, y, _opts ->
        send(self(), {tag, {x, y}})
        {:noreply, s}
      end)
    end

    test "approach destination is an adjacent cell within range, never the target's cell" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {14, 14, "prontera"}}
      end)

      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _r -> [] end)
      stub_open_terrain()
      capture_moves(:approach)

      {:noreply, returned} = CombatActionHandler.handle_attack_request(approach_state(), 2000, 7)

      assert returned.game_state.action_state == :combat_moving
      assert_received {:approach, {dest_x, dest_y}}
      assert max(abs(dest_x - 14), abs(dest_y - 14)) == 1
      refute {dest_x, dest_y} == {14, 14}
    end

    test "approach uses the adjoining cell even when another unit occupies it" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)

      # Unit 5000 already stands on the adjoining approach cell.
      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {14, 14, "prontera"}}
        :mob, 5000 -> {:ok, {13, 13, "prontera"}}
      end)

      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _r -> [{:mob, 5000}] end)
      stub_open_terrain()
      capture_moves(:approach)

      {:noreply, returned} = CombatActionHandler.handle_attack_request(approach_state(), 2000, 7)

      assert returned.game_state.action_state == :combat_moving
      assert_received {:approach, {dest_x, dest_y}}
      assert {dest_x, dest_y} == {13, 13}
      refute {dest_x, dest_y} == {14, 14}
      assert max(abs(dest_x - 14), abs(dest_y - 14)) == 1
    end

    test "approach treats a corpse cell as unoccupied" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {14, 14, "prontera"}}
        :player, 5000 -> {:ok, {13, 13, "prontera"}}
      end)

      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _r -> [{:player, 5000}] end)

      stub(UnitRegistry, :get_unit, fn :player, 5000 ->
        {:ok,
         {PlayerState, %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}, nil}}
      end)

      stub_open_terrain()
      capture_moves(:approach)

      {:noreply, returned} = CombatActionHandler.handle_attack_request(approach_state(), 2000, 7)

      assert returned.game_state.action_state == :combat_moving
      assert_received {:approach, {13, 13}}
    end

    test "approach treats an unresolved player cell as unoccupied" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {14, 14, "prontera"}}
        :player, 5000 -> {:ok, {13, 13, "prontera"}}
      end)

      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _r -> [{:player, 5000}] end)
      stub(UnitRegistry, :get_unit, fn :player, 5000 -> {:error, :not_found} end)
      stub_open_terrain()
      capture_moves(:approach)

      {:noreply, returned} = CombatActionHandler.handle_attack_request(approach_state(), 2000, 7)

      assert returned.game_state.action_state == :combat_moving
      assert_received {:approach, {13, 13}}
    end

    test "attacks when another unit occupies the arrival cell" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)

      # Target mob at {20,20}; the player arrived on {21,20}, but unit 5000 is
      # already standing on {21,20} (a simultaneous move).
      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {20, 20, "prontera"}}
        :mob, 5000 -> {:ok, {21, 20, "prontera"}}
      end)

      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _r -> [{:mob, 5000}] end)
      stub_open_terrain()
      reject(&MovementHandler.handle_request_move/4)

      stub(Combat, :execute_attack, fn _stats, game_state, 2000, _recalculate ->
        send(self(), :attacked)
        {:ok, game_state}
      end)

      state = approach_state(%{x: 21, y: 20, combat_target_id: 2000})

      {:noreply, _returned} = CombatActionHandler.handle_reached_attack_position(state)

      assert_received :attacked
    end

    test "attacks from the arrival cell when it is not occupied by another unit" do
      stub(Stats, :weapon_type, fn _equipment -> :dagger end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {20, 20, "prontera"}}
      end)

      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _r -> [] end)

      stub(Combat, :execute_attack, fn _stats, game_state, 2000, _recalculate ->
        send(self(), :attacked)
        {:ok, game_state}
      end)

      state = approach_state(%{x: 21, y: 20, combat_target_id: 2000})

      {:noreply, _returned} = CombatActionHandler.handle_reached_attack_position(state)

      assert_received :attacked
    end
  end

  describe "swing position anchoring" do
    alias Aesir.ZoneServer.Unit.Broadcast

    defp anchor_state(extra) do
      game_state =
        %PlayerState{
          character_id: 1000,
          x: 21,
          y: 20,
          map_name: "prontera",
          view_range: 14,
          action_state: :idle,
          movement_state: :standing,
          walk_path: [],
          last_attack_timestamp: 0,
          act_delay_until: 0,
          combat_action_type: 7,
          combat_target_id: 2000,
          stats: %{derived_stats: %{aspd: 150}, equipment: %Equipment{}}
        }
        |> Map.merge(Map.new(extra))

      %{game_state: game_state, connection_pid: self()}
    end

    defp stub_swing_at_adjacent_target do
      stub(Stats, :weapon_type, fn _equipment -> :fist end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {20, 20, "prontera"}}
      end)

      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _r -> [] end)

      stub(Combat, :execute_attack, fn _stats, game_state, 2000, _recalculate ->
        {:ok, game_state}
      end)
    end

    test "a swing on arrival from a combat approach sends the authoritative cell" do
      stub_swing_at_adjacent_target()

      stub(Broadcast, :to_in_range, fn "prontera", 21, 20, _range, packet, _opts ->
        send(self(), {:broadcast, packet})
        :ok
      end)

      state = anchor_state(%{action_state: :combat_moving})

      {:noreply, _returned} = CombatActionHandler.handle_reached_attack_position(state)

      assert_received {:send, :gameplay, {:move_stop, %MoveStop{gid: 1000, x: 21, y: 20}}}
      assert_received {:broadcast, %MoveStop{gid: 1000, x: 21, y: 20}}
    end

    test "a swing cutting a walk short halts the walk at the current cell" do
      stub_swing_at_adjacent_target()
      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet, _opts -> :ok end)

      state =
        anchor_state(%{
          action_state: :moving,
          movement_state: :moving,
          walk_path: [{22, 20}, {23, 20}]
        })

      {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 7)

      assert returned.game_state.movement_state == :standing
      assert returned.game_state.walk_path == []
      assert_received {:send, :gameplay, {:move_stop, %MoveStop{gid: 1000, x: 21, y: 20}}}
    end

    test "a steady auto-attack swing sends no position packet" do
      stub_swing_at_adjacent_target()
      reject(&Broadcast.to_in_range/6)

      state = anchor_state(%{action_state: :attacking})

      {:noreply, _returned} = CombatActionHandler.handle_auto_attack(state, 2000)

      refute_received {:send, :gameplay, {:move_stop, _}}
    end
  end

  # Free Cast lets its owner attack with a cast in flight (the cast becomes an
  # overlay) and through the after-cast act delay. A caster without Free Cast
  # stays blocked while casting.
  describe "Free Cast attack overlays" do
    alias Aesir.ZoneServer.Unit.Broadcast

    @freecast_id 278

    defp freecast_attack_state(extra) do
      progression = %PlayerProgression{learned_skills: Map.get(extra, :learned_skills, %{})}

      game_state =
        %PlayerState{
          character_id: 1000,
          x: 21,
          y: 20,
          map_name: "prontera",
          view_range: 14,
          action_state: :idle,
          movement_state: :standing,
          walk_path: [],
          last_attack_timestamp: 0,
          act_delay_until: 0,
          combat_action_type: 7,
          combat_target_id: 2000,
          stats: %{
            derived_stats: %{aspd: 150},
            equipment: %Equipment{},
            progression: progression
          }
        }
        |> Map.merge(Map.new(Map.drop(extra, [:learned_skills])))

      %{game_state: game_state, connection_pid: self()}
    end

    defp stub_in_range_swing do
      stub(Stats, :weapon_type, fn _equipment -> :fist end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {20, 20, "prontera"}}
      end)

      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _r -> [] end)
      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet, _opts -> :ok end)

      stub(Combat, :execute_attack, fn _stats, game_state, 2000, _recalculate ->
        {:ok, game_state}
      end)
    end

    test "a standing Free Caster swings mid-cast and keeps the cast running" do
      stub_in_range_swing()

      state =
        freecast_attack_state(%{
          action_state: :casting,
          casting: %{token: make_ref(), skill_id: 29, skill_level: 1},
          learned_skills: %{@freecast_id => 5}
        })

      assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 7)

      assert returned.game_state.action_state == :attacking
      refute returned.game_state.casting == nil
    end

    test "a standing caster without Free Cast cannot swing mid-cast" do
      stub_in_range_swing()
      reject(&Combat.execute_attack/4)

      cast = %{token: make_ref(), skill_id: 29, skill_level: 1}
      state = freecast_attack_state(%{action_state: :casting, casting: cast})

      assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 7)

      assert returned.game_state.action_state == :casting
      assert returned.game_state.casting == cast
    end

    test "Free Cast lets its owner attack through the after-cast act delay" do
      stub_in_range_swing()
      future = System.monotonic_time(:millisecond) + 60_000

      state =
        freecast_attack_state(%{
          act_delay_until: future,
          learned_skills: %{@freecast_id => 5}
        })

      assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 7)
      assert returned.game_state.action_state == :attacking
    end

    test "a caster without Free Cast is still blocked by the after-cast act delay" do
      reject(&Combat.execute_attack/4)
      future = System.monotonic_time(:millisecond) + 60_000

      state = freecast_attack_state(%{act_delay_until: future})

      assert {:noreply, returned} = CombatActionHandler.handle_attack_request(state, 2000, 7)
      assert returned.game_state.action_state == :idle
    end
  end
end
