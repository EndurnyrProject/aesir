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
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    stub(StatusInterpreter, :can_use_skill?, fn _type, _id -> true end)
    :ok
  end

  describe "handle_message/2 inbound skill dispatch" do
    test "a SkillCast casts use_skill with the same skill/level/target" do
      state = %{game_state: %PlayerState{character_id: 1000}}

      assert {:noreply, ^state} =
               PacketHandler.handle_message(
                 %SkillCast{skill_id: 29, level: 1, target_id: 2000},
                 state
               )

      assert_received {:"$gen_cast", {:use_skill, 29, 1, 2000}}
    end

    test "a GroundSkillCast casts use_skill_ground with the same skill/level/cell" do
      state = %{game_state: %PlayerState{character_id: 1000}}

      assert {:noreply, ^state} =
               PacketHandler.handle_message(
                 %GroundSkillCast{skill_id: 89, level: 1, x: 12, y: 12},
                 state
               )

      assert_received {:"$gen_cast", {:use_skill_ground, 89, 1, 12, 12}}
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
      assert length(skills) == 12

      sword = Enum.find(skills, &(&1.skill_id == 2))
      assert %SkillInfo{name: "SM_SWORD", level: 3} = sword
    end
  end

  # Plain-map game state used for the instant path, where Catalog is stubbed
  # with a definition that has no cast time.
  defp instant_state(sp) do
    %{
      connection_pid: self(),
      game_state: %{
        character_id: 1000,
        map_name: "prontera",
        x: 150,
        y: 150,
        skill_cooldowns: %{},
        act_delay_until: 0,
        action_state: :idle,
        state_context: %{},
        pending_inventory_persist: [],
        pending_inventory_notify: [],
        stats: %{
          base_stats: %{dex: 1, int: 1},
          current_state: %{sp: sp, hp: 100},
          derived_stats: %{max_sp: 200, max_hp: 100},
          progression: %{learned_skills: %{29 => 1}}
        }
      }
    }
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
    test "applies the effect, recalculates stats, persists, syncs and broadcasts" do
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)
      stub(PlayerStats, :calculate_stats, fn stats, 1000 -> stats end)
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
      stub(PlayerStats, :calculate_stats, fn stats, 1000 -> stats end)
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
      stub(PlayerStats, :calculate_stats, fn stats, 1000 -> stats end)
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
      stub(PlayerStats, :calculate_stats, fn stats, 1000 -> stats end)
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
      stub(PlayerStats, :calculate_stats, fn stats, 1000 -> stats end)
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

      stub(PlayerStats, :calculate_stats, fn stats, 1000 -> stats end)
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
      stub(Interpreter, :begin_cast, fn _gs, _id, _lvl, _target -> {:error, :out_of_range} end)
      reject(&CharacterPersistence.update_character/3)

      s = instant_state(30)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill_ground(s, 89, 1, 12, 12)
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
      stub(PlayerStats, :calculate_stats, fn stats, 1000 -> stats end)
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
      stub(StatusInterpreter, :can_use_skill?, fn :player, 1000 -> false end)
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
      stub(StatusInterpreter, :can_use_skill?, fn :player, 1000 -> false end)
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

    test "a skill cast is rejected while attacking" do
      reject(&Interpreter.begin_cast/4)

      s = casting_state(45, :attacking)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill(s, 29, 1, 1000)
    end

    test "a status landing during a timed cast drops to idle without committing" do
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      assert {:noreply, casting} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)
      token = casting.game_state.state_context.token

      stub(StatusInterpreter, :can_use_skill?, fn :player, 1000 -> false end)
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
      interruptible: interruptible
    }

    {:ok, casting} = PlayerState.transition_to(state.game_state, :casting, context)
    %{state | game_state: casting}
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
