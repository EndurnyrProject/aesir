defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.CastCancel
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillCasting
  alias Aesir.Net.SkillCooldown
  alias Aesir.Net.SkillEffect
  alias Aesir.Net.SkillInfo
  alias Aesir.Net.SkillList
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaCastcancel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillTextInputHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
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

      # Swordman tree resolves to its 7 point-learnable SM_* skills plus
      # NV_BASIC inherited from the Novice tree; quest skills are grant-only
      # and hidden until learned.
      assert length(skills) == 8

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

  defp snap_state do
    base = PlayerState.new(character())

    stats =
      base.stats
      |> put_in([Access.key!(:current_state), Access.key!(:sp)], 30)
      |> put_in([Access.key!(:progression), Access.key!(:learned_skills)], %{264 => 1})

    %SessionState{connection_pid: self(), game_state: %{base | stats: stats}}
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

    %SessionState{connection_pid: self(), game_state: game_state}
  end

  # Real Swordman PlayerState carrying one learned SM_SWORD level, used to drive
  # the on-enter skill-tree send through handle_map_loaded.
  defp map_loaded_state do
    base = PlayerState.new(%{character() | class: 1})

    stats =
      base.stats
      |> put_in([Access.key!(:progression), Access.key!(:job_id)], 1)
      |> put_in([Access.key!(:progression), Access.key!(:learned_skills)], %{2 => 3})

    %SessionState{connection_pid: self(), game_state: %{base | stats: stats}}
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
    test "a committed Snap moves through Movement and blocks Asura for two seconds" do
      directive = %ForcedMovement{map_name: "prontera", x: 152, y: 150}
      state = snap_state()

      stub(Interpreter, :begin_cast, fn game_state, 264, 1, {:ground, 152, 150} ->
        {:instant, PlayerState.put_pending_forced_movement(game_state, directive)}
      end)

      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)
      stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
      stub(StatusSync, :send_param, fn _connection, _param, _value -> :ok end)
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet, _opts -> :ok end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _state -> :ok end)

      stub(Aesir.ZoneServer.Unit.Movement, :set_position, fn :player, 1000, _state, "prontera" ->
        :ok
      end)

      assert {:noreply, %{game_state: moved}} =
               SkillHandler.handle_use_skill_ground(state, 264, 1, 152, 150)

      assert {moved.x, moved.y} == {152, 150}
      assert moved.pending_forced_movement == nil
      assert moved.skill_cooldowns[271] > System.monotonic_time(:millisecond)
    end

    test "a failed Snap leaves position and Asura cooldown unchanged" do
      state = snap_state()

      stub(Interpreter, :begin_cast, fn _game_state, 264, 1, {:ground, 152, 150} ->
        {:error, :invalid_target}
      end)

      assert {:noreply, %{game_state: unchanged}} =
               SkillHandler.handle_use_skill_ground(state, 264, 1, 152, 150)

      assert {unchanged.x, unchanged.y} == {150, 150}
      assert unchanged.skill_cooldowns == %{}
    end

    test "an incompatible skill request cancels an open Monk combo" do
      state = instant_state(100)
      combo = Combo.open(Combo.new(), :quadruple, {:mob, 2000}, 9_999_999_999)
      state = %{state | game_state: %{state.game_state | combo: combo}}

      expect(Interpreter, :begin_cast, fn game_state, 29, 1, :self ->
        assert game_state.combo.stage == :idle
        {:error, :invalid_target}
      end)

      assert {:noreply, returned} = SkillHandler.handle_use_skill(state, 29, 1, 1000)
      assert returned.game_state.combo.stage == :idle
    end

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

    test "committing a sphere cost advances its authoritative revision" do
      state = casting_state(45)

      spheres =
        Enum.reduce(1..2, SpiritSpheres.new(), fn _, acc ->
          {next, _entry} = SpiritSpheres.summon(acc, 60_000, 5)
          next
        end)

      {:ok, consumed, _entries} = SpiritSpheres.consume(spheres, 2)
      state = put_in(state.game_state.spirit_spheres, spheres)
      game_state = state.game_state
      committed_game_state = %{game_state | spirit_spheres: consumed}

      expect(Interpreter, :begin_cast, fn ^game_state, 29, 1, :self ->
        {:instant, committed_game_state}
      end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(Broadcast, :to_visible_players, fn _state, _packet, _opts -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      assert {:noreply, committed} = SkillHandler.handle_use_skill(state, 29, 1, 1000)
      assert SpiritSpheres.count(committed.game_state.spirit_spheres) == 0
      assert committed.game_state.spirit_sphere_revision == 1
      assert committed.game_state.spirit_sphere_timer == nil
    end

    test "a failed state commit performs no outward cast effects" do
      state = casting_state(45)

      spheres =
        Enum.reduce(1..2, SpiritSpheres.new(), fn _, acc ->
          {next, _entry} = SpiritSpheres.summon(acc, 60_000, 5)
          next
        end)

      {:ok, consumed, _entries} = SpiritSpheres.consume(spheres, 1)
      timer_ref = Process.send_after(self(), :existing_sphere_timer, 60_000)
      state = put_in(state.game_state.spirit_spheres, spheres)
      state = put_in(state.game_state.spirit_sphere_timer, timer_ref)
      game_state = state.game_state
      committed_game_state = %{game_state | spirit_spheres: consumed}

      expect(Interpreter, :begin_cast, fn ^game_state, 29, 1, :self ->
        {:instant, committed_game_state}
      end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)

      expect(UnitRegistry, :update_unit_state, fn :player, 1000, committed ->
        assert SpiritSpheres.count(committed.spirit_spheres) == 1
        assert committed.spirit_sphere_revision == 1
        assert committed.spirit_sphere_timer_generation == 1
        assert committed.spirit_sphere_timer == nil
        assert %{generation: 1, expires_at: _expires_at} = committed.spirit_sphere_timer_plan
        raise "commit failed"
      end)

      reject(&CharacterPersistence.update_character/3)
      reject(&StatusSync.send_stat_updates/2)
      reject(&StatusSync.send_param/3)
      reject(&Broadcast.to_in_range/5)
      reject(&Broadcast.to_visible_players/3)

      assert_raise RuntimeError, "commit failed", fn ->
        SkillHandler.handle_use_skill(state, 29, 1, 1000)
      end

      assert is_integer(Process.read_timer(timer_ref))
      assert Process.cancel_timer(timer_ref)
    end

    test "instant deferred results retain the outcome without committing resources or timers" do
      state = casting_state(45)
      game_state = state.game_state
      descriptor = deferred_descriptor()

      expect(Interpreter, :begin_cast, fn ^game_state, 29, 1, :self ->
        {:deferred, game_state, descriptor}
      end)

      reject(&CharacterPersistence.update_character/3)
      reject(&StatusSync.send_stat_updates/2)

      assert {:noreply, deferred} = SkillHandler.handle_use_skill(state, 29, 1, 1000)
      assert deferred.game_state == game_state

      assert %{
               descriptor: ^descriptor,
               target_id: 2000,
               token: token,
               timer_ref: timer_ref
             } = deferred.deferred_skill_result

      assert is_reference(token)
      assert is_reference(timer_ref)

      assert {deferred_result, retained} = SkillHandler.take_deferred_skill_result(deferred)
      assert deferred_result == deferred.deferred_skill_result
      assert retained.deferred_skill_result == nil
    end

    test "timed deferred results retain the completion outcome without commitment" do
      state = interrupting_state(45, fixed_offset: 1_000)
      game_state = state.game_state
      token = game_state.casting.token
      descriptor = deferred_descriptor()

      expect(Interpreter, :complete_cast, fn ^game_state, 29, 1, :self ->
        {:deferred, game_state, descriptor}
      end)

      reject(&CharacterPersistence.update_character/3)
      reject(&StatusSync.send_stat_updates/2)

      assert {:noreply, deferred} = SkillHandler.handle_cast_complete(state, token)
      assert deferred.game_state.stats.current_state.sp == 45
      assert deferred.game_state.skill_cooldowns == %{}
      assert deferred.game_state.act_delay_until == 0
      assert deferred.game_state.action_state == :idle
      assert deferred.game_state.casting == nil
      assert %{descriptor: ^descriptor, target_id: 2000} = deferred.deferred_skill_result

      assert {deferred_result, retained} = SkillHandler.take_deferred_skill_result(deferred)
      refute Map.has_key?(deferred_result, :game_state)
      assert retained.game_state.action_state == :idle
      assert retained.game_state.casting == nil
    end

    test "a matching absorb reply settles current SP before adding the reward" do
      state = instant_state(45)
      game_state = state.game_state
      descriptor = deferred_descriptor()

      expect(Interpreter, :begin_cast, fn ^game_state, 29, 1, :self ->
        {:deferred, game_state, descriptor}
      end)

      assert {:noreply, pending} = SkillHandler.handle_use_skill(state, 29, 1, 1000)
      %{token: token} = pending.deferred_skill_result
      stats = pending.game_state.stats
      current_stats = put_in(stats.current_state.sp, 30)
      current = %{pending.game_state | stats: current_stats}
      pending = %{pending | game_state: current}
      charged_stats = put_in(current_stats.current_state.sp, 25)
      charged = %{current | stats: charged_stats}

      expect(Interpreter, :settle_deferred, fn ^current, ^descriptor -> {:ok, charged} end)
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [], cooldown: [])} end)
      stub_commit()

      assert {:noreply, settled} =
               SkillHandler.handle_spirit_absorb_result(pending, token, 2000, 2)

      assert settled.game_state.stats.current_state.sp == 39
      assert settled.deferred_skill_result == nil
    end

    test "timeout clears a deferred absorb and a late result is ignored" do
      state = instant_state(45)
      game_state = state.game_state
      descriptor = deferred_descriptor()

      expect(Interpreter, :begin_cast, fn ^game_state, 29, 1, :self ->
        {:deferred, game_state, descriptor}
      end)

      assert {:noreply, pending} = SkillHandler.handle_use_skill(state, 29, 1, 1000)
      %{token: token} = pending.deferred_skill_result

      assert {:noreply, timed_out} = SkillHandler.handle_deferred_timeout(pending, token)
      assert timed_out.deferred_skill_result == nil
      assert timed_out.game_state.stats.current_state.sp == 45

      assert {:noreply, ^timed_out} =
               SkillHandler.handle_spirit_absorb_result(timed_out, token, 2000, 2)
    end

    test "a transfer descriptor commits source costs before its single delivery" do
      state = instant_state(45)
      {spheres, _entry} = SpiritSpheres.summon(state.game_state.spirit_spheres, 60_000, 5)
      game_state = %{state.game_state | spirit_spheres: spheres}

      descriptor = %Interpreter.Deferred{
        effect: {:transfer_sphere, 2000},
        cost: %Cost{sp: 40, spheres: 1},
        zeny: 0,
        skill_id: 29,
        level: 1,
        target: {:unit, 2000}
      }

      {:ok, consumed, _entry} = SpiritSpheres.consume(spheres, 1)
      stats = game_state.stats
      charged_stats = put_in(stats.current_state.sp, 5)
      charged = %{game_state | stats: charged_stats, spirit_spheres: consumed}

      expect(Interpreter, :begin_cast, fn ^game_state, 29, 1, {:unit, 2000} ->
        {:deferred, game_state, descriptor}
      end)

      expect(Interpreter, :settle_deferred, fn ^game_state, ^descriptor -> {:ok, charged} end)
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [], cooldown: [])} end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(Broadcast, :to_visible_players, fn _state, _update, [exclude_id: 1000] -> :ok end)

      expect(UnitRegistry, :update_unit_state, fn :player, 1000, committed ->
        assert committed.stats.current_state.sp == 5
        assert SpiritSpheres.count(committed.spirit_spheres) == 0
        Process.put(:source_committed, true)
        :ok
      end)

      expect(UnitRegistry, :get_unit, fn :player, 2000 ->
        assert Process.get(:source_committed)
        {:ok, {PlayerState, casting_state(10).game_state, self()}}
      end)

      assert {:noreply, committed} =
               SkillHandler.handle_use_skill(%{state | game_state: game_state}, 29, 1, 2000)

      assert committed.game_state.stats.current_state.sp == 5
      assert SpiritSpheres.count(committed.game_state.spirit_spheres) == 0

      assert_receive {:"$gen_cast", {:receive_spirit_sphere, %{source_id: 1000, target_id: 2000}}}
    end

    test "a local absorb settles its cost before applying the capped reward" do
      state = instant_state(100)
      stats = state.game_state.stats
      stats = put_in(stats.derived_stats.max_sp, 100)
      state = %{state | game_state: %{state.game_state | stats: stats}}
      game_state = state.game_state

      descriptor = %Interpreter.Deferred{
        effect: {:absorb_local, 14},
        cost: %Cost{sp: 5},
        zeny: 0,
        skill_id: 262,
        level: 1,
        target: :self
      }

      charged_stats = put_in(stats.current_state.sp, 95)
      charged = %{game_state | stats: charged_stats}

      expect(Interpreter, :begin_cast, fn ^game_state, 262, 1, :self ->
        {:deferred, game_state, descriptor}
      end)

      expect(Interpreter, :settle_deferred, fn ^game_state, ^descriptor -> {:ok, charged} end)
      stub(Catalog, :by_id, fn 262 -> {:ok, definition(id: 262, cast_time: [], cooldown: [])} end)
      stub_commit()

      assert {:noreply, settled} = SkillHandler.handle_use_skill(state, 262, 1, 1000)
      assert settled.game_state.stats.current_state.sp == 100
    end

    test "pending skill text rejects AC_MAKINGARROW before cost or dialog startup" do
      stub(Broadcast, :to_player, fn 1000, %SkillCastFailed{} -> :ok end)

      timer_ref = Process.send_after(self(), :skill_text_timeout, 60_000)

      pending = %SessionState.PendingSkillTextInput{
        request_id: 42,
        skill_id: 9_001,
        level: 1,
        target: {:ground, 151, 150},
        timer_ref: timer_ref
      }

      state =
        casting_state(30)
        |> put_in(
          [
            Access.key!(:game_state),
            Access.key!(:stats),
            Access.key!(:progression),
            Access.key!(:learned_skills)
          ],
          %{147 => 1}
        )
        |> put_in(
          [
            Access.key!(:game_state),
            Access.key!(:stats),
            Access.key!(:progression),
            Access.key!(:job_id)
          ],
          3
        )
        |> Map.put(:interaction_lock, nil)
        |> Map.put(:pending_skill_text_input, pending)

      assert {:noreply, unchanged} = SkillHandler.handle_use_skill(state, 147, 1, 1000)
      assert unchanged.game_state.stats.current_state.sp == 30
      assert unchanged.pending_skill_text_input == pending
      assert unchanged.interaction_lock == nil
      refute_received {:send, _, {:npc_dialog, _}}
      Process.cancel_timer(timer_ref)
    end

    test "a staged pending_interaction starts a dialog and takes the lock" do
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(Broadcast, :to_player, fn 1000, %SkillCastFailed{} -> :ok end)
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
            Access.key!(:game_state),
            Access.key!(:stats),
            Access.key!(:progression),
            Access.key!(:learned_skills)
          ],
          %{147 => 1}
        )
        |> put_in(
          [
            Access.key!(:game_state),
            Access.key!(:stats),
            Access.key!(:progression),
            Access.key!(:job_id)
          ],
          3
        )
        |> Map.put(:interaction_lock, nil)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(state, 147, 1, 1000)

      assert {pid, _ref, 0x6000_0000} = new_state.interaction_lock
      assert is_pid(pid)
      assert new_state.game_state.pending_interaction == nil
      assert_receive {:send, _, {:npc_dialog, %Aesir.Net.NpcDialog{expect: :CLOSE}}}

      assert {:noreply, rejected_stage} =
               SkillTextInputHandler.stage(new_state, 9_001, 1, {:ground, 151, 150})

      assert rejected_stage.interaction_lock == new_state.interaction_lock
      assert rejected_stage.pending_skill_text_input == nil
    end

    # SA_AUTOSPELL (279) is the first skill whose cast/4 stages a SkillMenu offer.
    # Its real 3s fixed cast is stubbed away so the instant path exercises the
    # drain; the offer is sent and parked only after the cast commits its SP.
    test "a staged pending_menu_offer sends the SkillMenu and parks it on the session" do
      autospell =
        struct!(%Definition{
          id: 279,
          name: :sa_autospell,
          display_name: "Hindsight",
          max_level: 10,
          target_type: :self,
          sp_cost: List.duplicate(35, 10)
        })

      stub(Catalog, :by_id, fn 279 -> {:ok, autospell} end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      state =
        instant_state(50)
        |> Map.put(:pending_skill_menu, nil)
        |> put_in(
          [
            Access.key!(:game_state),
            Access.key!(:stats),
            Access.key!(:progression),
            Access.key!(:learned_skills)
          ],
          %{279 => 10, 19 => 10, 14 => 10}
        )

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(state, 279, 10, 1000)

      assert_receive {:send, :world,
                      {:skill_menu,
                       %Aesir.Net.SkillMenu{
                         src_skill_id: 279,
                         kind: :SKILLS,
                         entry_ids: [19, 14]
                       }}}

      assert new_state.pending_skill_menu == %{
               skill_id: 279,
               kind: :SKILLS,
               entry_ids: [19, 14],
               level: 10
             }

      assert new_state.game_state.pending_menu_offer == nil
      assert new_state.game_state.stats.current_state.sp == 15
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

    test "a per-level range list sizes the walk with the cast level's range, not the widest level's" do
      stub(Interpreter, :begin_cast, fn _gs, 29, 1, {:unit, 2000} -> {:error, :out_of_range} end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {160, 150, "prontera"}}
      end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(range: [3, 5, 7, 9, 11])} end)
      stub(MapCache, :get, fn "prontera" -> {:ok, :map_data} end)

      # Level 1's range is 3, not the definition's widest (level 5) range of 11:
      # sizing off 11 would read the target (10 cells away) as already in range
      # and never call find_path at all.
      expect(Pathfinding, :find_path, fn :map_data, {150, 150}, {157, 150} ->
        {:ok, [{151, 150}]}
      end)

      test_pid = self()

      stub(MovementHandler, :handle_request_move, fn state, x, y, opts ->
        send(test_pid, {:move, state.game_state, x, y, opts})
        {:noreply, state}
      end)

      assert {:noreply, _} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 2000)

      # The approach targets the optimal cell itself (157,150, sized off the
      # level's range of 3); find_path only gates reachability.
      assert_received {:move, _moving_gs, 157, 150, opts}
      assert Keyword.get(opts, :skill_initiated) == true
    end

    test "an out-of-range skill does not approach a corpse" do
      state = casting_state(45)
      corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

      Mimic.copy(TargetResolver)
      stub(Interpreter, :begin_cast, fn _gs, 29, 1, {:unit, 2_000} -> {:error, :out_of_range} end)
      stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), corpse, :player} end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2_000 -> {:error, :not_found}
        :mob, 2_000 -> {:ok, {160, 150, "prontera"}}
      end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(range: 9)} end)
      stub(MapCache, :get, fn "prontera" -> {:ok, :map_data} end)

      stub(Pathfinding, :find_path, fn :map_data, {150, 150}, {151, 150} ->
        {:ok, [{151, 150}]}
      end)

      reject(&MovementHandler.handle_request_move/4)

      assert {:noreply, ^state} = SkillHandler.handle_use_skill(state, 29, 1, 2_000)
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

      state = %SessionState{connection_pid: self(), game_state: moving}

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

  describe "SA_CASTCANCEL" do
    test "cancels the in-flight cast, charges its own 2 SP and zaps the penalty" do
      stub_commit()

      state = cast_cancel_state(45)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(state, 275, 1, 1000)

      gs = new_state.game_state
      assert gs.action_state == :idle
      assert gs.casting == nil
      # 45 - 2 (Cast Cancel's own cost) - 16 (AL_INCAGI lv1: 18 * 90 / 100).
      assert gs.stats.current_state.sp == 27
    end

    test "the cancelled skill never fires: its timer is dead and its token is inert" do
      stub_commit()
      # AL_INCAGI's effect must never land, before or after the replay below.
      reject(&StatusInterpreter.apply_status/4)

      state = cast_cancel_state(45)
      token = state.game_state.casting.token
      timer_ref = state.game_state.casting.timer_ref

      assert {:noreply, cancelled} = SkillHandler.handle_use_skill(state, 275, 1, 1000)

      # The cast timer was cancelled, so it can never deliver its message.
      assert Process.cancel_timer(timer_ref) == false

      # Belt and braces: even replaying the exact token (as an already-queued
      # {:cast_complete, token} in the mailbox would) resolves nothing.
      assert {:noreply, replayed} = SkillHandler.handle_cast_complete(cancelled, token)

      assert replayed == cancelled
      assert replayed.game_state.stats.current_state.sp == 27
    end

    test "cancelling with no cast in flight fails through the normal path, charging nothing" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      reject(&CharacterPersistence.update_character/3)

      state = cast_cancel_state(45)
      idle = %{state | game_state: %{state.game_state | action_state: :idle, casting: nil}}

      assert {:noreply, unchanged} = SkillHandler.handle_use_skill(idle, 275, 1, 1000)

      assert unchanged == idle
      assert unchanged.game_state.stats.current_state.sp == 45

      assert_received {:to_player,
                       %SkillCastFailed{
                         skill_id: 275,
                         reason: :SKILL_CAST_FAILURE_REASON_UNSPECIFIED
                       }}
    end

    test "SaCastcancel.validate/4 rejects :not_casting when no cast is in flight" do
      definition = SaCastcancel.definition()

      assert SaCastcancel.validate(%PlayerState{casting: nil}, :self, 1, definition) ==
               {:error, :not_casting}

      assert SaCastcancel.validate(%PlayerState{casting: %{skill_id: 29}}, :self, 1, definition) ==
               :ok
    end

    test "a higher Cast Cancel level zaps a smaller penalty, at every level" do
      stub_commit()

      # AL_INCAGI lv1 costs 18 SP: 18 * (90 - 20*(lv-1)) / 100, floored.
      penalties =
        for level <- 1..5 do
          assert {:noreply, new_state} =
                   SkillHandler.handle_use_skill(cast_cancel_state(45), 275, level, 1000)

          # Back out the zap from Cast Cancel's own 2 SP.
          45 - 2 - new_state.game_state.stats.current_state.sp
        end

      assert penalties == [16, 12, 9, 5, 1]
      assert penalties == Enum.sort(penalties, :desc)
      assert Enum.uniq(penalties) == penalties
    end
  end

  describe "skill action-gating" do
    test "the reusable gate rechecks a status that lands between staging and resume" do
      state = casting_state(45)
      assert {:ok, ^state} = SkillHandler.cast_gate(state, 125)

      stub(StatusInterpreter, :can_use_skill?, fn :player, 1000, 125 -> false end)

      assert {:error, :status_blocked} = SkillHandler.cast_gate(state, 125)
      assert state.game_state.stats.current_state.sp == 45
    end

    test "the reusable gate rejects a dead caster before checking status or action" do
      state = casting_state(45)
      dead_game_state = %{state.game_state | action_state: :dead}
      dead = %{state | game_state: dead_game_state}

      reject(&StatusInterpreter.can_use_skill?/3)
      assert {:error, :dead} = SkillHandler.cast_gate(dead, 125)
    end

    test "a rejected cast sends its failure reason to the caster" do
      stub(Interpreter, :begin_cast, fn _game_state, 12, 1, {:ground, 12, 12} ->
        {:error, :missing_catalyst}
      end)

      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)

      s = casting_state(45)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill_ground(s, 12, 1, 12, 12)

      assert_received {:to_player,
                       %SkillCastFailed{
                         skill_id: 12,
                         reason: :SKILL_CAST_FAILURE_REASON_MISSING_CATALYST
                       }}
    end

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
      assert_receive {:combat, {:auto_attack, 2000}}
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
      assert_receive {:combat, {:auto_attack, 2000}}
    end

    test "an instant cast with no lock does not start an auto-attack loop" do
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [], cooldown: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, 1000, _sc, _ -> :ok end)
      stub_commit()

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(instant_state(30), 29, 1, 1000)

      assert new_state.game_state.combat_target_id == nil
      refute_receive {:combat, {:auto_attack, _}}
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
      refute_receive {:combat, {:auto_attack, _}}
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

      state = %SessionState{connection_pid: self(), game_state: moving}

      assert {:noreply, new_state} = SkillHandler.handle_reached_skill_position(state)

      assert new_state.game_state.combat_target_id == 2000
      assert is_reference(new_state.game_state.continuous_attack_timer)
      assert_receive {:combat, {:auto_attack, 2000}}
    end

    test "a damage interrupt keeps the lock and resumes auto-attack" do
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      state = interrupting_state(45, fixed_offset: -100, combat_target_id: 2000)

      result = SkillHandler.interrupt_cast_on_damage(state)

      assert result.game_state.action_state == :idle
      assert result.game_state.combat_target_id == 2000
      assert is_reference(result.game_state.continuous_attack_timer)
      assert_receive {:combat, {:auto_attack, 2000}}
    end

    test "a manual-move cancel drops the lock and does not resume" do
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      state = interrupting_state(45, fixed_offset: 60_000, combat_target_id: 2000)

      result = SkillHandler.cancel_cast(state, :move)

      assert result.game_state.action_state == :idle
      assert result.game_state.combat_target_id == nil
      refute_receive {:combat, {:auto_attack, _}}
    end
  end

  defp locked_attacking_state(sp) do
    s = casting_state(sp, :attacking)
    %{s | game_state: %{s.game_state | combat_target_id: 2000, combat_action_type: 7}}
  end

  # A live AL_INCAGI lv1 cast (18 SP at that level) with SA_CASTCANCEL learned to
  # its max, so the zap is measured against a real catalog SP cost.
  defp cast_cancel_state(sp) do
    state = interrupting_state(sp, fixed_offset: -100)

    learned = %{29 => 10, 275 => 5}

    game_state =
      put_in(
        state.game_state,
        [Access.key!(:stats), Access.key!(:progression), Access.key!(:learned_skills)],
        learned
      )

    %{state | game_state: game_state}
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

    test "AL_TELEPORT broadcasts a SkillEffect at the pre-warp position before the warp lands" do
      base = instant_state(30)

      staged = %{base.game_state | pending_warp: {"morocc", 155, 95}}

      expect(Interpreter, :begin_cast, fn _gs, 26, 1, :self -> {:instant, staged} end)
      stub(Catalog, :by_id, fn 26 -> {:ok, definition(id: 26, cooldown: [])} end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      # Simulates the real WarpHandler: it mutates map/x/y on the returned
      # session, so a broadcast reading the post-commit state would read the
      # arrival position instead of the departure one.
      stub(WarpHandler, :warp, fn session_state, "morocc", 155, 95 ->
        {:ok,
         %{
           session_state
           | game_state: %{session_state.game_state | map_name: "morocc", x: 155, y: 95}
         }}
      end)

      test_pid = self()

      stub(Broadcast, :to_in_range, fn map_name, x, y, _range, packet ->
        send(test_pid, {:broadcast, map_name, x, y, packet})
        :ok
      end)

      assert {:noreply, _new_state} = SkillHandler.handle_use_skill(base, 26, 1, 1000)

      assert_received {:broadcast, "prontera", 150, 150,
                       %SkillEffect{skill_id: 26, level: 1, src_id: 1000, target_id: 1000}}
    end
  end

  describe "no-damage support skills reach clients as SkillEffect" do
    test "AL_CURE broadcasts a SkillEffect on cast" do
      stub(Catalog, :by_id, fn 35 -> {:ok, definition(id: 35, cooldown: [])} end)
      stub(Interpreter, :begin_cast, fn gs, 35, 1, {:unit, 2000} -> {:instant, gs} end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      test_pid = self()

      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, packet ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      assert {:noreply, _} = SkillHandler.handle_use_skill(instant_state(30), 35, 1, 2000)

      assert_received {:broadcast,
                       %SkillEffect{skill_id: 35, level: 1, src_id: 1000, target_id: 2000}}
    end

    test "PR_STRECOVERY broadcasts a SkillEffect on cast" do
      stub(Catalog, :by_id, fn 72 -> {:ok, definition(id: 72, cooldown: [])} end)
      stub(Interpreter, :begin_cast, fn gs, 72, 1, {:unit, 2000} -> {:instant, gs} end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      test_pid = self()

      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, packet ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      assert {:noreply, _} = SkillHandler.handle_use_skill(instant_state(30), 72, 1, 2000)

      assert_received {:broadcast,
                       %SkillEffect{skill_id: 72, level: 1, src_id: 1000, target_id: 2000}}
    end
  end

  defp deferred_descriptor do
    %Interpreter.Deferred{
      effect: {:absorb_player, 2000},
      cost: %Cost{sp: 5},
      zeny: 0,
      skill_id: 29,
      level: 1,
      target: :self
    }
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
