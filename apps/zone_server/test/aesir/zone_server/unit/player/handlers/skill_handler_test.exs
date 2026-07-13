defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.CastCancel
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCasting
  alias Aesir.Net.SkillCooldown
  alias Aesir.Net.SkillEffect
  alias Aesir.Net.SkillInfo
  alias Aesir.Net.SkillList
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    stub(StatusInterpreter, :can_use_skill?, fn _type, _id, _skill -> true end)
    :ok
  end

  describe "handle_message/2 inbound skill dispatch" do
    test "a SkillCast dispatches use_skill with the same skill/level/target" do
      state = %{game_state: %PlayerState{character_id: 1000}}

      expect(SkillHandler, :handle_use_skill, fn st, 29, 1, 2000 -> {:noreply, st} end)

      assert {:noreply, ^state} =
               PacketHandler.handle_message(
                 %SkillCast{skill_id: 29, level: 1, target_id: 2000},
                 state
               )
    end

    test "a GroundSkillCast dispatches use_skill_ground with the same skill/level/cell" do
      state = %{game_state: %PlayerState{character_id: 1000}}

      expect(SkillHandler, :handle_use_skill_ground, fn st, 89, 1, 12, 12 -> {:noreply, st} end)

      assert {:noreply, ^state} =
               PacketHandler.handle_message(
                 %GroundSkillCast{skill_id: 89, level: 1, x: 12, y: 12},
                 state
               )
    end
  end

  describe "skill tree on map load" do
    test "sends the full available tree, learned levels reflected" do
      stub(StatusSync, :send_params, fn _conn, _params -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)

      assert {:noreply, _} = PacketHandler.handle_message(%MapLoaded{}, map_loaded_state())

      assert_received {:send, :bulk, {:skill_list, %SkillList{skills: skills}}}

      # Swordman tree resolves to its 10 implemented SM_* skills plus the two
      # implemented Novice skills inherited from the Novice tree.
      assert length(skills) == 13

      sword = Enum.find(skills, &(&1.skill_id == 2))
      assert %SkillInfo{name: "SM_SWORD", level: 3} = sword
    end
  end

  defp instant_state(sp) do
    state = casting_state(sp)

    stats =
      state.game_state.stats
      |> put_in([Access.key!(:current_state), Access.key!(:hp)], 100)
      |> put_in([Access.key!(:derived_stats), Access.key!(:max_sp)], 200)
      |> put_in([Access.key!(:derived_stats), Access.key!(:max_hp)], 100)
      |> put_in([Access.key!(:progression), Access.key!(:learned_skills)], %{29 => 1})

    state
    |> Map.put(:interaction_lock, nil)
    |> Map.put(:game_state, %{state.game_state | stats: stats})
  end

  # Real PlayerState used for the timed-cast path, where transition_to needs a
  # genuine struct. AL_INCAGI (id 29) is a real 800ms cast self-cast on the ally.
  defp casting_state(sp, action_state \\ :idle) do
    base = PlayerState.new(character())

    stats =
      base.stats
      |> put_in([Access.key!(:base_stats), Access.key!(:dex)], 1)
      |> put_in([Access.key!(:base_stats), Access.key!(:int)], 1)
      |> put_in([Access.key!(:current_state), Access.key!(:sp)], sp)
      |> put_in([Access.key!(:progression), Access.key!(:learned_skills)], %{29 => 10})

    game_state = %{base | action_state: action_state, stats: stats}

    %{connection_pid: self(), game_state: game_state}
  end

  # Real Swordman PlayerState carrying one learned SM_SWORD level, used to drive
  # the on-enter skill-tree send through handle_map_loaded.
  defp map_loaded_state do
    base = PlayerState.new(%{character() | class: 1})

    stats =
      base.stats
      |> put_in([Access.key!(:progression), Access.key!(:job_id)], 1)
      |> put_in([Access.key!(:progression), Access.key!(:learned_skills)], %{2 => 3})

    %{connection_pid: self(), game_state: %{base | stats: stats}}
  end

  defp character do
    %Aesir.Commons.Models.Character{
      id: 1000,
      account_id: 2000,
      name: "Caster",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
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

  describe "instant cast" do
    test "publishes the final resource projection after consuming SP" do
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      state = casting_state(45)
      game_state = %{state.game_state | party_id: 7}
      stats = game_state.stats

      expect(Manager, :sync_member, fn 7, 1000, member ->
        assert member == %Member{
                 char_id: 1000,
                 name: "Caster",
                 job_id: stats.progression.job_id,
                 base_level: stats.progression.base_level,
                 hp: stats.current_state.hp,
                 max_hp: stats.derived_stats.max_hp,
                 sp: 27,
                 max_sp: stats.derived_stats.max_sp,
                 ap: stats.current_state.ap,
                 max_ap: stats.derived_stats.max_ap,
                 online: true,
                 map_name: "prontera"
               }

        {:ok, %{}}
      end)

      assert {:noreply, %{game_state: %{stats: %{current_state: %{sp: 27}}}}} =
               SkillHandler.handle_use_skill(%{state | game_state: game_state}, 29, 1, 1000)
    end

    test "a staged pending_interaction starts a dialog and takes the lock" do
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      # Real catalog entry: AC_MAKINGARROW (147) is an instant self-cast whose
      # cast/4 stages pending_interaction. The empty fixture inventory makes the
      # dialog close immediately with the no-materials notice. A real
      # PlayerState is required: the drain builds a Ctx from the session.
      state =
        casting_state(30)
        |> put_in(
          [
            :game_state,
            Access.key!(:stats),
            Access.key!(:progression),
            Access.key!(:learned_skills)
          ],
          %{147 => 1}
        )
        |> Map.put(:interaction_lock, nil)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(state, 147, 1, 1000)

      assert {pid, _ref, 0x6000_0000} = new_state.interaction_lock
      assert is_pid(pid)
      assert new_state.game_state.pending_interaction == nil
      assert_receive {:send, _, {:npc_dialog, %Aesir.Net.NpcDialog{expect: :CLOSE}}}
    end

    test "applies the effect, recalculates stats, persists, syncs and broadcasts" do
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      expect(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      expect(CharacterPersistence, :update_character, fn 1000, %{sp: 12}, _opts -> {:ok, %{}} end)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(instant_state(30), 29, 1, 1000)
      assert new_state.game_state.stats.current_state.sp == 12
      refute_received {:send_packet, %SkillCasting{}}
    end

    test "a no-damage support skill broadcasts a SkillEffect" do
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      test_pid = self()

      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, packet ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      assert {:noreply, _} = SkillHandler.handle_use_skill(instant_state(30), 29, 1, 1000)

      assert_received {:broadcast,
                       %SkillEffect{skill_id: 29, level: 1, src_id: 1000, target_id: 1000}}
    end

    test "failed cast leaves state unchanged and does not persist" do
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      reject(&CharacterPersistence.update_character/3)
      reject(&StatusInterpreter.apply_status/4)

      s = instant_state(1)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill(s, 29, 1, 1000)
    end

    test "drains pending_inventory_notify on commit, emitting ItemAdded for the produced item" do
      item = %InventoryItem{nameid: 523, amount: 1, identify: 1}

      base = instant_state(30)

      staged =
        base.game_state
        |> Map.put(:inventory, %{0 => item})
        |> Map.put(:pending_inventory_notify, [{:added, 0, item}])

      expect(Interpreter, :begin_cast, fn _gs, 31, 1, :self -> {:instant, staged} end)
      stub(Catalog, :by_id, fn 31 -> {:ok, definition(id: 31, cooldown: [])} end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(base, 31, 1, 1000)

      assert_received {:send, :gameplay, {:item_added, %ItemAdded{nameid: 523}}}
      assert new_state.game_state.pending_inventory_notify == []
    end

    test "sends ZC_SKILL_POSTDELAY when the skill has a cooldown" do
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [], cooldown: [5_000])} end)

      assert {:noreply, _} = SkillHandler.handle_use_skill(instant_state(30), 29, 1, 1000)

      assert_received {:send, :gameplay,
                       {:skill_cooldown, %SkillCooldown{skill_id: 29, tick: 5_000}}}
    end

    test "sends no ZC_SKILL_POSTDELAY when the skill has no cooldown" do
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [], cooldown: [])} end)

      assert {:noreply, _} = SkillHandler.handle_use_skill(instant_state(30), 29, 1, 1000)
      refute_received {:send, :gameplay, {:skill_cooldown, %SkillCooldown{}}}
    end

    test "ground cast recalculates stats, persists and broadcasts no SkillEffect" do
      expect(Interpreter, :begin_cast, fn gs, 89, 1, {:ground, 12, 12} ->
        {:instant, %{gs | stats: %{gs.stats | current_state: %{gs.stats.current_state | sp: 12}}}}
      end)

      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Catalog, :by_id, fn 89 -> {:ok, definition(id: 89, cooldown: [])} end)
      reject(&Broadcast.to_in_range/5)
      reject(&Broadcast.to_in_range/6)
      expect(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      expect(CharacterPersistence, :update_character, fn 1000, %{sp: 12}, _opts -> {:ok, %{}} end)

      assert {:noreply, new_state} =
               SkillHandler.handle_use_skill_ground(instant_state(30), 89, 1, 12, 12)

      assert new_state.game_state.stats.current_state.sp == 12
    end

    test "failed ground cast leaves state unchanged and does not persist" do
      # A genuine failure (not :out_of_range, which now triggers move-to-range).
      stub(Interpreter, :begin_cast, fn _gs, _id, _lvl, _target -> {:error, :invalid_target} end)
      reject(&CharacterPersistence.update_character/3)

      s = instant_state(30)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill_ground(s, 89, 1, 12, 12)
    end
  end

  describe "move-to-range on out-of-range cast" do
    test "an out-of-range unit skill walks the caster toward the target instead of fizzling" do
      stub(Interpreter, :begin_cast, fn _gs, 29, 1, {:unit, 2000} -> {:error, :out_of_range} end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {160, 150, "prontera"}}
      end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(range: 9)} end)
      stub(MapCache, :get, fn "prontera" -> {:ok, :map_data} end)

      stub(Pathfinding, :find_path, fn :map_data, {150, 150}, {151, 150} ->
        {:ok, [{151, 150}]}
      end)

      test_pid = self()

      stub(MovementHandler, :handle_request_move, fn state, x, y, opts ->
        send(test_pid, {:move, state.game_state, x, y, opts})
        {:noreply, state}
      end)

      assert {:noreply, _} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 2000)

      # Target sits 10 cells east of a range-9 skill: approach cell is one step in.
      assert_received {:move, moving_gs, 151, 150, opts}
      assert Keyword.get(opts, :skill_initiated) == true
      assert moving_gs.action_state == :skill_moving
      assert moving_gs.movement_intent == :skill

      assert moving_gs.state_context == %{
               skill_id: 29,
               skill_level: 1,
               target: {:unit, 2000},
               combat_target_id: nil
             }
    end

    test "reaching casting range re-dispatches the pending skill from context" do
      test_pid = self()

      stub(Interpreter, :begin_cast, fn _gs, skill_id, level, target ->
        send(test_pid, {:redispatch, skill_id, level, target})
        {:error, :insufficient_sp}
      end)

      {:ok, moving} =
        PlayerState.transition_to(
          casting_state(45).game_state,
          :skill_moving,
          %{skill_id: 29, skill_level: 1, target: {:unit, 2000}}
        )

      state = %{connection_pid: self(), game_state: moving}

      assert {:noreply, new_state} = SkillHandler.handle_reached_skill_position(state)

      assert_received {:redispatch, 29, 1, {:unit, 2000}}
      assert new_state.game_state.action_state == :idle
    end

    test "gives up (no move, stays idle) when no path reaches the target" do
      stub(Interpreter, :begin_cast, fn _gs, 29, 1, {:unit, 2000} -> {:error, :out_of_range} end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {160, 150, "prontera"}}
      end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(range: 9)} end)
      stub(MapCache, :get, fn "prontera" -> {:ok, :map_data} end)

      stub(Pathfinding, :find_path, fn :map_data, {150, 150}, {151, 150} -> {:error, :blocked} end)

      reject(&MovementHandler.handle_request_move/4)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 2000)
      assert new_state.game_state.action_state == :idle
    end
  end

  describe "ammo-depletion stat recalc" do
    @ammo_bit EquipLocation.location_bit(:ammo)

    test "a cast depleting the last arrow recalcs stats from the post-depletion equipment" do
      test_pid = self()

      # The interpreter has already taken the last arrow: its slot is gone and the
      # bow remains equipped. The removal is staged for the handler to persist.
      arrow = %InventoryItem{nameid: 1750, amount: 1, equip: @ammo_bit}
      bow = %InventoryItem{nameid: 1101, amount: 1, equip: 2}
      old_inv = %{0 => arrow, 1 => bow}
      new_inv = %{1 => bow}

      base = instant_state(30)

      staged =
        base.game_state
        |> Map.put(:inventory, new_inv)
        |> Map.put(:pending_inventory_persist, [{old_inv, new_inv, {:removed, 0}}])

      expect(Interpreter, :begin_cast, fn _gs, 46, 1, {:unit, 2000} -> {:instant, staged} end)

      stub(Catalog, :by_id, fn 46 ->
        {:ok, definition(id: 46, cooldown: [], damage_type: :damage)}
      end)

      stub(InventoryOps, :apply_change, fn 1000, _old, _new, {:removed, 0} -> {:ok, new_inv} end)

      stub(PlayerStats, :calculate_stats, fn stats, 1000, equipped ->
        send(test_pid, {:recalced, equipped})
        stats
      end)

      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(base, 46, 1, 2000)

      # Recalc ran with current equipment (3-arity): the bow survives, the spent
      # arrow is gone, so its ATK/element drops out instead of lingering.
      assert_received {:recalced, [%InventoryItem{nameid: 1101}]}
      refute Map.has_key?(new_state.game_state.inventory, 0)
    end
  end

  describe "timed cast" do
    test "enters :casting, sends a cast bar, schedules a timer and does not deduct SP" do
      stub(Broadcast, :to_player, fn 1000, %SkillCasting{} -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)
      reject(&CharacterPersistence.update_character/3)
      reject(&StatusInterpreter.apply_status/4)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)

      gs = new_state.game_state
      assert gs.action_state == :casting
      assert gs.state_context.skill_id == 29
      assert gs.state_context.skill_level == 1
      assert gs.state_context.target == :self
      assert gs.state_context.interruptible == true
      assert is_reference(gs.state_context.timer_ref)
      assert is_reference(gs.state_context.token)
      # SP untouched until the cast completes.
      assert gs.stats.current_state.sp == 45
    end

    test "cast bar carries the caster, self target and total cast time" do
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:cast_bar, packet}) end)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)

      assert_received {:cast_bar, %SkillCasting{} = packet}
      assert packet.src_id == 1000
      assert packet.target_id == 1000
      assert packet.x == 0
      assert packet.y == 0
      assert packet.skill_id == 29
      assert packet.property == 0

      assert packet.cast_time ==
               new_state.game_state.state_context.total_until -
                 new_state.game_state.state_context.started_at
    end

    test "completing a matching token runs the behavior, deducts SP and returns to idle" do
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      assert {:noreply, casting} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)
      token = casting.game_state.state_context.token

      assert {:noreply, completed} = SkillHandler.handle_cast_complete(casting, token)

      gs = completed.game_state
      assert gs.action_state == :idle
      assert gs.state_context == %{}
      assert gs.stats.current_state.sp == 45 - 18
    end

    test "a stale token is ignored and the cast continues" do
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)
      reject(&CharacterPersistence.update_character/3)
      reject(&StatusInterpreter.apply_status/4)

      assert {:noreply, casting} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)

      assert {:noreply, unchanged} = SkillHandler.handle_cast_complete(casting, make_ref())
      assert unchanged == casting
      assert unchanged.game_state.action_state == :casting
      assert unchanged.game_state.stats.current_state.sp == 45
    end

    test "a moving player is stopped before the cast starts" do
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      state = casting_state(45, :moving)

      state = %{
        state
        | game_state: %{state.game_state | movement_state: :moving, walk_path: [{151, 150}]}
      }

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(state, 29, 1, 1000)

      assert new_state.game_state.action_state == :casting
      assert new_state.game_state.movement_state == :standing
      assert new_state.game_state.walk_path == []
    end
  end

  describe "cast interruption" do
    test "damage in the variable phase cancels the cast with no SP loss" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      state = interrupting_state(45, fixed_offset: -100)
      timer_ref = state.game_state.state_context.timer_ref

      result = SkillHandler.interrupt_cast_on_damage(state)

      assert result.game_state.action_state == :idle
      assert result.game_state.state_context == %{}
      assert result.game_state.stats.current_state.sp == 45
      assert_received {:to_player, %CastCancel{gid: 1000}}
      assert Process.cancel_timer(timer_ref) == false
    end

    test "damage in the fixed phase leaves the cast untouched" do
      reject(&Broadcast.to_player/2)

      state = interrupting_state(45, fixed_offset: 60_000)

      result = SkillHandler.interrupt_cast_on_damage(state)

      assert result == state
      assert result.game_state.action_state == :casting
      refute_received {:to_player, %CastCancel{}}
    end

    test "a non-interruptible cast in the variable phase is immune" do
      reject(&Broadcast.to_player/2)

      state = interrupting_state(45, fixed_offset: -100, interruptible: false)

      assert SkillHandler.interrupt_cast_on_damage(state) == state
    end

    test "damage on a non-casting player is a no-op" do
      reject(&Broadcast.to_player/2)

      state = casting_state(45, :idle)

      assert SkillHandler.interrupt_cast_on_damage(state) == state
    end

    test "movement cancels the cast regardless of phase" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      state = interrupting_state(45, fixed_offset: 60_000)
      timer_ref = state.game_state.state_context.timer_ref

      result = SkillHandler.cancel_cast(state, :move)

      assert result.game_state.action_state == :idle
      assert_received {:to_player, %CastCancel{gid: 1000}}
      assert Process.cancel_timer(timer_ref) == false
    end

    test "cancelling a non-casting player is a no-op" do
      reject(&Broadcast.to_player/2)

      state = casting_state(45, :idle)

      assert SkillHandler.cancel_cast(state, :move) == state
    end
  end

  describe "skill action-gating" do
    test "a no_skill player calling handle_use_skill gets a CastCancel and no cast is driven" do
      stub(StatusInterpreter, :can_use_skill?, fn :player, 1000, _skill -> false end)
      reject(&Interpreter.begin_cast/4)
      reject(&Catalog.by_id/1)

      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      s = casting_state(45)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill(s, 29, 1, 1000)

      assert s.game_state.action_state == :idle
      assert_received {:to_player, %CastCancel{gid: 1000}}
    end

    test "a no_skill player calling handle_use_skill_ground gets a CastCancel and no cast is driven" do
      stub(StatusInterpreter, :can_use_skill?, fn :player, 1000, _skill -> false end)
      reject(&Interpreter.begin_cast/4)
      reject(&Catalog.by_id/1)

      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      s = casting_state(45)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill_ground(s, 89, 1, 12, 12)

      assert s.game_state.action_state == :idle
      assert_received {:to_player, %CastCancel{gid: 1000}}
    end

    test "an instant skill is rejected while a timed cast is in flight" do
      reject(&Interpreter.begin_cast/4)
      reject(&CharacterPersistence.update_character/3)
      reject(&StatusInterpreter.apply_status/4)

      s = casting_state(45, :casting)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill(s, 29, 1, 1000)
    end

    test "a ground skill is rejected while a timed cast is in flight" do
      reject(&Interpreter.begin_cast/4)

      s = casting_state(45, :casting)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill_ground(s, 89, 1, 12, 12)
    end

    test "a skill cast while auto-attacking stops the pending swing and drives the cast" do
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      swing_timer = Process.send_after(self(), {:auto_attack, 2000}, 60_000)

      base = casting_state(45, :attacking)

      s = %{
        base
        | game_state: %{
            base.game_state
            | combat_target_id: 2000,
              combat_action_type: 7,
              continuous_attack_timer: swing_timer
          }
      }

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(s, 29, 1, 1000)

      assert new_state.game_state.action_state == :casting
      # Starting the cast dropped through :idle, cancelling the queued swing.
      assert Process.cancel_timer(swing_timer) == false
    end

    test "a status landing during a timed cast drops to idle without committing" do
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      assert {:noreply, casting} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)
      token = casting.game_state.state_context.token

      stub(StatusInterpreter, :can_use_skill?, fn :player, 1000, _skill -> false end)
      reject(&Interpreter.complete_cast/4)
      reject(&CharacterPersistence.update_character/3)

      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)

      assert {:noreply, dropped} = SkillHandler.handle_cast_complete(casting, token)

      assert dropped.game_state.action_state == :idle
      assert dropped.game_state.state_context == %{}
      assert dropped.game_state.stats.current_state.sp == 45
      assert_received {:to_player, %CastCancel{gid: 1000}}
    end
  end

  describe "skills preserve the lock and resume auto-attack" do
    setup do
      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {150, 150, "prontera"}}
      end)

      :ok
    end

    test "an instant cast while locked re-sets the lock and reschedules auto-attack" do
      stub(Interpreter, :begin_cast, fn gs, 29, 1, {:unit, 2000} -> {:instant, gs} end)
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [], cooldown: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, 1000, _sc, _ -> :ok end)
      stub_commit()

      assert {:noreply, new_state} =
               SkillHandler.handle_use_skill(locked_attacking_state(45), 29, 1, 2000)

      assert new_state.game_state.combat_target_id == 2000
      assert is_reference(new_state.game_state.continuous_attack_timer)
      assert_receive {:auto_attack, 2000}
    end

    test "a timed cast completing while locked re-sets the lock and reschedules auto-attack" do
      stub_commit()
      stub(StatusInterpreter, :apply_status, fn :player, _id, _sc, _ -> :ok end)

      assert {:noreply, casting} =
               SkillHandler.handle_use_skill(locked_attacking_state(45), 29, 1, 2000)

      assert casting.game_state.action_state == :casting
      token = casting.game_state.state_context.token

      assert {:noreply, completed} = SkillHandler.handle_cast_complete(casting, token)

      assert completed.game_state.action_state == :idle
      assert completed.game_state.combat_target_id == 2000
      assert is_reference(completed.game_state.continuous_attack_timer)
      assert_receive {:auto_attack, 2000}
    end

    test "an instant cast with no lock does not start an auto-attack loop" do
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [], cooldown: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, 1000, _sc, _ -> :ok end)
      stub_commit()

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(instant_state(30), 29, 1, 1000)

      assert new_state.game_state.combat_target_id == nil
      refute_receive {:auto_attack, _}
    end

    test "a cast whose locked target has died does not resume" do
      stub(SpatialIndex, :get_unit_position, fn _type, _id -> {:error, :not_found} end)
      stub(Interpreter, :begin_cast, fn gs, 29, 1, {:unit, 2000} -> {:instant, gs} end)
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [], cooldown: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, _id, _sc, _ -> :ok end)
      stub_commit()

      assert {:noreply, new_state} =
               SkillHandler.handle_use_skill(locked_attacking_state(45), 29, 1, 2000)

      assert new_state.game_state.combat_target_id == nil
      refute_receive {:auto_attack, _}
    end

    test "a locked skill that walked into range resumes auto-attack after casting" do
      stub(Interpreter, :begin_cast, fn gs, 29, 1, {:unit, 2000} -> {:instant, gs} end)
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [], cooldown: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, _id, _sc, _ -> :ok end)
      stub_commit()

      {:ok, moving} =
        PlayerState.transition_to(
          casting_state(45).game_state,
          :skill_moving,
          %{skill_id: 29, skill_level: 1, target: {:unit, 2000}, combat_target_id: 2000}
        )

      state = %{connection_pid: self(), game_state: moving}

      assert {:noreply, new_state} = SkillHandler.handle_reached_skill_position(state)

      assert new_state.game_state.combat_target_id == 2000
      assert is_reference(new_state.game_state.continuous_attack_timer)
      assert_receive {:auto_attack, 2000}
    end

    test "a damage interrupt keeps the lock and resumes auto-attack" do
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      state = interrupting_state(45, fixed_offset: -100, combat_target_id: 2000)

      result = SkillHandler.interrupt_cast_on_damage(state)

      assert result.game_state.action_state == :idle
      assert result.game_state.combat_target_id == 2000
      assert is_reference(result.game_state.continuous_attack_timer)
      assert_receive {:auto_attack, 2000}
    end

    test "a manual-move cancel drops the lock and does not resume" do
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      state = interrupting_state(45, fixed_offset: 60_000, combat_target_id: 2000)

      result = SkillHandler.cancel_cast(state, :move)

      assert result.game_state.action_state == :idle
      assert result.game_state.combat_target_id == nil
      refute_receive {:auto_attack, _}
    end
  end

  defp locked_attacking_state(sp) do
    s = casting_state(sp, :attacking)
    %{s | game_state: %{s.game_state | combat_target_id: 2000, combat_action_type: 7}}
  end

  defp stub_commit do
    stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
    stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
    stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)
    stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
    stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)
  end

  # Builds a real :casting state with a live cast-complete timer and a controllable
  # phase. `fixed_offset` is added to `now`: negative = variable phase (past),
  # positive = fixed phase (future).
  defp interrupting_state(sp, opts) do
    fixed_offset = Keyword.fetch!(opts, :fixed_offset)
    interruptible = Keyword.get(opts, :interruptible, true)

    state = casting_state(sp)
    now = System.monotonic_time(:millisecond)
    token = make_ref()
    timer_ref = Process.send_after(self(), {:cast_complete, token}, 60_000)

    context = %{
      skill_id: 29,
      skill_level: 1,
      target: :self,
      element: :neutral,
      started_at: now,
      fixed_until: now + fixed_offset,
      total_until: now + 60_000,
      timer_ref: timer_ref,
      token: token,
      interruptible: interruptible,
      combat_target_id: Keyword.get(opts, :combat_target_id)
    }

    {:ok, casting} = PlayerState.transition_to(state.game_state, :casting, context)
    %{state | game_state: casting}
  end

  describe "commit_cast warp drain" do
    test "staged pending_warp causes WarpHandler.warp/4 to be called with the right args" do
      base = instant_state(30)

      staged = %{base.game_state | pending_warp: {"morocc", 155, 95}}

      expect(Interpreter, :begin_cast, fn _gs, 26, 1, :self -> {:instant, staged} end)
      stub(Catalog, :by_id, fn 26 -> {:ok, definition(id: 26, cooldown: [])} end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      expect(WarpHandler, :warp, fn session_state, "morocc", 155, 95 ->
        {:ok, session_state}
      end)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(base, 26, 1, 1000)
      assert Map.get(new_state.game_state, :pending_warp) == nil
    end

    test "pending_warp is cleared even when WarpHandler returns an error" do
      base = instant_state(30)

      staged = %{base.game_state | pending_warp: {"unknown_map", 0, 0}}

      expect(Interpreter, :begin_cast, fn _gs, 26, 1, :self -> {:instant, staged} end)
      stub(Catalog, :by_id, fn 26 -> {:ok, definition(id: 26, cooldown: [])} end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      stub(WarpHandler, :warp, fn _session_state, "unknown_map", 0, 0 ->
        {:error, :map_not_found}
      end)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(base, 26, 1, 1000)
      assert Map.get(new_state.game_state, :pending_warp) == nil
    end

    test "WarpHandler is not called when pending_warp is nil" do
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)
      reject(&WarpHandler.warp/4)

      assert {:noreply, _} = SkillHandler.handle_use_skill(instant_state(30), 29, 1, 1000)
    end
  end

  defp definition(fields) do
    struct!(
      %Definition{
        id: 29,
        name: :al_incagi,
        display_name: "Increase AGI",
        max_level: 10,
        sp_cost: [18]
      },
      fields
    )
  end
end
