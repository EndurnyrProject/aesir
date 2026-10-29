defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
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
  alias Aesir.Net.SystemNotice
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.Skill.CastEnd
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
  alias Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillTextInputHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.SkillRequest
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
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

  # The player knows `skill_id` at `level`, as a request needs to reach its cast.
  defp now, do: System.monotonic_time(:millisecond)

  defp knowing(%SessionState{} = state, skill_id, level),
    do: put_in(state.game_state.stats.progression.learned_skills[skill_id], level)

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

      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
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

    test "a support skill request keeps an open Monk combo" do
      state = instant_state(100)
      combo = Combo.open(Combo.new(), :quadruple, 9_999_999_999)
      state = %{state | game_state: %{state.game_state | combo: combo}}

      expect(Interpreter, :begin_cast, fn game_state, 29, 1, :self ->
        assert game_state.combo.stage == :quadruple
        {:error, :invalid_target}
      end)

      assert {:noreply, returned} = SkillHandler.handle_use_skill(state, 29, 1, 1000)
      assert returned.game_state.combo.stage == :quadruple
    end

    test "a refused ground request keeps an open Monk combo" do
      state = snap_state()
      combo = Combo.open(Combo.new(), :quadruple, 9_999_999_999)
      state = %{state | game_state: %{state.game_state | combo: combo}}

      expect(Interpreter, :begin_cast, fn game_state, 264, 1, {:ground, 152, 150} ->
        assert game_state.combo.stage == :quadruple
        {:error, :invalid_target}
      end)

      assert {:noreply, returned} = SkillHandler.handle_use_skill_ground(state, 264, 1, 152, 150)
      assert returned.game_state.combo.stage == :quadruple
    end

    test "Asura and the Champion combo skills keep the window on the retained target" do
      stub(UnitRegistry, :unit_exists?, fn :homunculus, _id -> false end)

      for skill_id <- [271, 371, 372] do
        state = instant_state(100)
        combo = Combo.open(Combo.new(), :extremity, 9_999_999_999)
        state = %{state | game_state: %{state.game_state | combo: combo}}

        expect(Interpreter, :begin_cast, fn game_state, ^skill_id, 1, {:unit, 2000} ->
          assert game_state.combo.stage == :extremity
          {:error, :invalid_target}
        end)

        SkillHandler.handle_use_skill(knowing(state, skill_id, 1), skill_id, 1, 2000)
      end
    end

    test "Asura aimed at another unit keeps the open window" do
      stub(UnitRegistry, :unit_exists?, fn :homunculus, _id -> false end)
      stub(Interpreter, :castbegin_passes?, fn _game_state, 271, 1, _target -> true end)
      state = instant_state(100)
      combo = Combo.open(Combo.new(), :extremity, 9_999_999_999)
      state = %{state | game_state: %{state.game_state | combo: combo}}

      expect(Interpreter, :begin_cast, fn game_state, 271, 1, {:unit, 2001} ->
        assert game_state.combo.stage == :extremity
        {:error, :invalid_target}
      end)

      SkillHandler.handle_use_skill(knowing(state, 271, 1), 271, 1, 2001)
    end

    test "a combo follow-up is aimed at the unit the player is attacking" do
      stub(UnitRegistry, :unit_exists?, fn :homunculus, _id -> false end)
      stub(Interpreter, :castbegin_passes?, fn _game_state, 272, 1, _target -> true end)
      state = instant_state(100)
      combo = Combo.open(Combo.new(), :quadruple, 9_999_999_999)

      state = %{
        state
        | game_state: %{state.game_state | combo: combo, combat_target_id: 2002}
      }

      expect(Interpreter, :begin_cast, fn _game_state, 272, 1, {:unit, 2002} ->
        {:error, :invalid_target}
      end)

      SkillHandler.handle_use_skill(knowing(state, 272, 1), 272, 1, 1000)
    end

    test "successful named skill use dispatches its equipment autobonus" do
      key = {10, 0}
      state = casting_state(45)

      stats = %{
        state.game_state.stats
        | equip_autobonuses: %{
            key => %{
              trigger: {:on_skill, 29},
              rate: 1_001,
              source_order: 0,
              source_identity: {:host, 501}
            }
          }
      }

      game_state = %{state.game_state | stats: stats}
      state = %{state | game_state: game_state}

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub(Interpreter, :begin_cast, fn ^game_state, 29, 1, :self -> {:instant, game_state} end)

      stub(StatusInterpreter, :on_committed_action, fn :player, 1000, {:skill, 29} ->
        :unchanged
      end)

      stub_commit()
      expect(UnitRegistry, :get_player_pid, fn 1000 -> {:ok, self()} end)

      assert {:noreply, _state} = SkillHandler.handle_use_skill(state, 29, 1, 1000)
      assert_received {:"$gen_cast", {:equipment, {:autobonus_activate, ^key, {:host, 501}}}}
    end

    test "rejected named skill use does not dispatch an equipment autobonus" do
      key = {10, 0}
      state = casting_state(45)

      stats = %{
        state.game_state.stats
        | equip_autobonuses: %{
            key => %{
              trigger: {:on_skill, 29},
              rate: 1_001,
              source_order: 0,
              source_identity: {:host, 501}
            }
          }
      }

      state = %{state | game_state: %{state.game_state | stats: stats}}

      stub(Interpreter, :begin_cast, fn _game_state, 29, 1, :self ->
        {:error, :invalid_target}
      end)

      stub(Broadcast, :to_player, fn 1000, %SkillCastFailed{} -> :ok end)
      reject(&UnitRegistry.get_player_pid/1)

      assert {:noreply, ^state} = SkillHandler.handle_use_skill(state, 29, 1, 1000)
      refute_received {:"$gen_cast", {:equipment, {:autobonus_activate, ^key, _}}}
    end

    test "a proc-cast skill use arms named-skill autobonuses like any other use" do
      key = {10, 0}
      state = casting_state(45)

      stats = %{
        state.game_state.stats
        | equip_autobonuses: %{
            key => %{
              trigger: {:on_skill, 29},
              rate: 1_001,
              source_order: 0,
              source_identity: {:host, 501}
            }
          }
      }

      state = %{state | game_state: %{state.game_state | stats: stats}}
      game_state = state.game_state

      stub(Interpreter, :proc_cast, fn ^game_state, 29, 1, :self -> {:ok, game_state} end)
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub_commit()
      expect(UnitRegistry, :get_player_pid, fn 1000 -> {:ok, self()} end)

      assert {:noreply, _state} = SkillHandler.handle_proc_cast(state, 29, 1, :self)
      assert_received {:"$gen_cast", {:equipment, {:autobonus_activate, ^key, {:host, 501}}}}
    end

    test "an equipment proc refused for its cooldown sends the refusal's reply before any roll" do
      state = casting_state(45)
      game_state = state.game_state
      parent = self()

      stub(Interpreter, :check_proc_usable, fn ^game_state, 29, nil ->
        {:error, {:not_ok, {:fail, :skill_interval}}}
      end)

      reject(&Interpreter.proc_cast/4)

      stub(Broadcast, :to_player, fn 1000, packet ->
        send(parent, {:packet, packet})
        :ok
      end)

      assert {:noreply, ^state} =
               SkillHandler.handle_equip_proc(state, equip_proc(:attack, rate: 0))

      assert_received {:packet,
                       %SkillCastFailed{
                         skill_id: 29,
                         reason: :SKILL_CAST_FAILURE_REASON_ON_COOLDOWN
                       }}

      stub(Interpreter, :check_proc_usable, fn ^game_state, 29, nil ->
        {:error, {:not_ok, :silent}}
      end)

      assert {:noreply, ^state} =
               SkillHandler.handle_equip_proc(state, equip_proc(:attack, rate: 0))

      refute_received {:packet, _packet}
    end

    test "an on-skill proc casts without an after-cast delay and cannot re-trigger itself" do
      state = casting_state(45)

      on_skill =
        for skill_id <- [29, 30] do
          %{
            trigger_skill: 29,
            skill_id: skill_id,
            level: 1,
            rate: 1_000,
            flag: 0,
            force: 1,
            card_id: 0
          }
        end

      [entry, other] = Enum.with_index(on_skill, fn proc, index -> {:on_skill, index, proc} end)

      state =
        put_in(state.game_state.stats.modifiers.equipment, %{{:auto_cast, :on_skill} => on_skill})

      game_state = state.game_state

      stub(Interpreter, :check_proc_usable, fn ^game_state, 29, nil -> :ok end)

      expect(Interpreter, :proc_cast, fn ^game_state,
                                         29,
                                         1,
                                         :self,
                                         [act_delay?: false, placement_skill: _] ->
        {:ok, game_state}
      end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub_commit()
      stub(UnitRegistry, :get_player_pid, fn 1000 -> {:ok, self()} end)

      assert {:noreply, _state} =
               SkillHandler.handle_equip_proc(state, equip_proc(:skill, entry: entry))

      assert_received {:"$gen_cast", {:skill, {:equip_proc, %{entry: ^other}}}}
      refute_received {:"$gen_cast", {:skill, {:equip_proc, %{entry: ^entry}}}}
    end

    test "an on-skill proc whose entry moved since it was selected still locks its own entry" do
      state = casting_state(45)

      proc = %{
        trigger_skill: 29,
        skill_id: 29,
        level: 1,
        rate: 1_000,
        flag: 0,
        force: 1,
        card_id: 0
      }

      # Selected at index 1; a refold since left it the only entry, at index 0.
      stale = {:on_skill, 1, proc}

      state =
        put_in(state.game_state.stats.modifiers.equipment, %{{:auto_cast, :on_skill} => [proc]})

      game_state = state.game_state

      stub(Interpreter, :check_proc_usable, fn ^game_state, 29, nil -> :ok end)

      expect(Interpreter, :proc_cast, fn ^game_state,
                                         29,
                                         1,
                                         :self,
                                         [act_delay?: false, placement_skill: _] ->
        {:ok, game_state}
      end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub_commit()
      stub(UnitRegistry, :get_player_pid, fn 1000 -> {:ok, self()} end)

      assert {:noreply, _state} =
               SkillHandler.handle_equip_proc(state, equip_proc(:skill, entry: stale))

      refute_received {:"$gen_cast", {:skill, {:equip_proc, _candidate}}}
    end

    test "a proc whose effect failed after its requirement commits the charged caster silently" do
      state = casting_state(45)
      game_state = state.game_state
      charged = put_in(game_state.stats.current_state.hp, 1)

      stub(Interpreter, :proc_cast, fn ^game_state, 29, 1, :self ->
        {:error, :no_effect, charged}
      end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub_commit()
      expect(UnitRegistry, :update_unit_state, fn :player, 1000, ^charged -> :ok end)
      reject(&Broadcast.to_player/2)

      assert {:noreply, %{game_state: %{stats: %{current_state: %{hp: 1}}}}} =
               SkillHandler.handle_proc_cast(state, 29, 1, :self)
    end

    test "a proc whose effect completed as a failure reports it and closes the use" do
      state = casting_state(45)
      game_state = state.game_state
      charged = put_in(game_state.stats.current_state.hp, 1)
      test_pid = self()

      stub(Interpreter, :proc_cast, fn ^game_state, 29, 1, :self ->
        {:failed, charged, :no_effect}
      end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub_commit()
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, ^charged -> :ok end)
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      expect(CastEnd, :complete, fn %{character_id: 1000}, 29, :self -> :ok end)

      assert {:noreply, %{game_state: %{stats: %{current_state: %{hp: 1}}}}} =
               SkillHandler.handle_proc_cast(state, 29, 1, :self)

      assert_received {:to_player, %SkillCastFailed{skill_id: 29}}
    end

    test "publishes the final resource projection after consuming SP" do
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)

      expect(StatusInterpreter, :on_committed_action, fn :player, 1000, {:skill, 29} ->
        :unchanged
      end)

      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
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
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
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
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)

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

      # An instant cast's start effects run inside the Interpreter, not here.
      reject(&StatusInterpreter.on_committed_action/3)

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

    test "timeout settles a deferred absorb without a reward and a late result is ignored" do
      state = instant_state(45)
      game_state = state.game_state
      paid = put_in(game_state.stats.current_state.sp, 40)
      descriptor = %{deferred_descriptor() | cost: %Cost{}}

      expect(Interpreter, :begin_cast, fn ^game_state, 29, 1, :self ->
        {:deferred, paid, descriptor}
      end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(after_cast_delay: [1_000])} end)
      stub_commit()
      before = System.monotonic_time(:millisecond)

      assert {:noreply, pending} = SkillHandler.handle_use_skill(state, 29, 1, 1000)
      %{token: token} = pending.deferred_skill_result
      assert pending.game_state.stats.current_state.sp == 40

      assert {:noreply, timed_out} = SkillHandler.handle_deferred_timeout(pending, token)
      assert timed_out.deferred_skill_result == nil
      assert timed_out.game_state.stats.current_state.sp == 40
      assert timed_out.game_state.act_delay_until >= before + 1_000

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
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
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

      assert_receive {:"$gen_cast",
                      {:skill, {:receive_spirit_sphere, %{source_id: 1000, target_id: 2000}}}}
    end

    test "a local absorb settles its cost before applying the capped reward" do
      state = instant_state(100)
      stats = state.game_state.stats
      stats = put_in(stats.derived_stats.max_sp, 100)
      state = knowing(%{state | game_state: %{state.game_state | stats: stats}}, 262, 1)
      stats = state.game_state.stats
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
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
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
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
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

      # Each mode's menu order: renewal lists Fire Bolt first, classic Cold Bolt.
      entry_ids = if GameMode.mode() == :renewal, do: [19, 14], else: [14, 19]

      assert_receive {:send, :world,
                      {:skill_menu,
                       %Aesir.Net.SkillMenu{
                         src_skill_id: 279,
                         kind: :SKILLS,
                         entry_ids: ^entry_ids
                       }}}

      assert new_state.pending_skill_menu == %{
               skill_id: 279,
               kind: :SKILLS,
               entry_ids: entry_ids,
               level: 10
             }

      assert new_state.game_state.pending_menu_offer == nil
      assert new_state.game_state.stats.current_state.sp == 15
    end

    test "applies the effect, recalculates stats, persists, syncs and broadcasts" do
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
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
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
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

    test "a no-damage cast on another unit shows its effect around that unit" do
      base = knowing(instant_state(30), 31, 1)

      stub(Interpreter, :begin_cast, fn gs, 31, 1, {:unit, _target} -> {:instant, gs} end)
      stub(Catalog, :by_id, fn 31 -> {:ok, definition(id: 31, cooldown: [])} end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      stub(TargetResolver, :resolve_target_position, fn
        2000 -> {:ok, :player, {160, 155, "prontera"}}
        {:player, 2000} -> {:ok, :player, {160, 155, "prontera"}}
      end)

      test_pid = self()

      stub(Broadcast, :to_in_range, fn map, x, y, _range, packet ->
        send(test_pid, {:broadcast, {map, x, y}, packet})
        :ok
      end)

      assert {:noreply, _} = SkillHandler.handle_use_skill(base, 31, 1, 2000)

      assert_received {:broadcast, {"prontera", 160, 155},
                       %SkillEffect{skill_id: 31, src_id: 1000, target_id: 2000}}

      stub(TargetResolver, :resolve_target_position, fn _gone -> {:error, :target_not_found} end)

      assert {:noreply, _} = SkillHandler.handle_use_skill(base, 31, 1, 2000)
      assert_received {:broadcast, {"prontera", 150, 150}, %SkillEffect{target_id: 2000}}
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
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      assert {:noreply, new_state} =
               SkillHandler.handle_use_skill(knowing(base, 31, 1), 31, 1, 1000)

      assert_received {:send, :gameplay, {:item_added, %ItemAdded{nameid: 523}}}
      assert new_state.game_state.pending_inventory_notify == []
    end

    test "sends ZC_SKILL_POSTDELAY when the skill has a cooldown" do
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
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
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
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

      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)

      stub(Catalog, :by_id, fn 89 ->
        {:ok, definition(id: 89, cooldown: [], target_type: :ground)}
      end)

      reject(&Broadcast.to_in_range/5)
      reject(&Broadcast.to_in_range/6)
      expect(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      expect(CharacterPersistence, :update_character, fn 1000, %{sp: 12}, _opts -> {:ok, %{}} end)

      assert {:noreply, new_state} =
               SkillHandler.handle_use_skill_ground(
                 knowing(instant_state(30), 89, 1),
                 89,
                 1,
                 12,
                 12
               )

      assert new_state.game_state.stats.current_state.sp == 12
    end

    test "a failed attempt commits the returned caster without cost or cooldown" do
      state = instant_state(30)
      before = state.game_state
      refreshed = put_in(before.stats.modifiers.status_effects[:dex], 5)

      expect(Interpreter, :begin_cast, fn ^before, 29, 1, :self ->
        {:error, :invalid_target, refreshed}
      end)

      expect(UnitRegistry, :update_unit_state, fn :player, 1000, ^refreshed -> :ok end)
      expect(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      expect(Broadcast, :to_player, fn 1000, %SkillCastFailed{skill_id: 29} -> :ok end)
      reject(&CharacterPersistence.update_character/3)

      assert {:noreply, committed} = SkillHandler.handle_use_skill(state, 29, 1, 1000)
      assert committed.game_state.stats.modifiers.status_effects.dex == 5
      assert committed.game_state.stats.current_state.sp == 30
      assert committed.game_state.skill_cooldowns == before.skill_cooldowns
    end

    test "failed ground cast leaves state unchanged and does not persist" do
      # A genuine failure (not :out_of_range, which now triggers move-to-range).
      stub(Interpreter, :begin_cast, fn _gs, _id, _lvl, _target -> {:error, :invalid_target} end)
      reject(&CharacterPersistence.update_character/3)

      s = knowing(instant_state(30), 89, 1)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill_ground(s, 89, 1, 12, 12)
    end
  end

  describe "item skill casts" do
    test "an out-of-range item cast ends silently, keeps the claim spent, and walks nowhere" do
      state = %{
        casting_state(45)
        | pending_item_skill: %{
            skill_id: 29,
            level: 1,
            keep_requirement?: false,
            item_index: 0,
            item_nameid: 601
          }
      }

      stub(Interpreter, :begin_item_cast, fn gs, 29, 1, {:unit, 2000}, _claim, false ->
        {:error, :out_of_range, gs, :after_start}
      end)

      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      reject(&MovementHandler.handle_request_move/4)
      reject(&Broadcast.to_player/2)

      assert {:noreply, dropped} = SkillHandler.handle_use_skill(state, 29, 1, 2000)

      # The item was spent, so the pending item skill loses its slot: a repeated
      # request can only fail its claim.
      assert dropped.pending_item_skill == %{skill_id: 29, level: 1, keep_requirement?: false}
    end

    test "a pending item skill with no claimable item fails silently" do
      state = %{
        casting_state(45)
        | pending_item_skill: %{skill_id: 29, level: 1, keep_requirement?: false}
      }

      stub(Interpreter, :begin_item_cast, fn gs, 29, 1, {:unit, 2000}, claim, false ->
        assert {:error, :missing_item} = claim.(gs)
        {:error, :missing_item}
      end)

      reject(&Broadcast.to_player/2)
      reject(&MovementHandler.handle_request_move/4)

      assert {:noreply, ^state} = SkillHandler.handle_use_skill(state, 29, 1, 2000)
    end

    test "a claimed no-consume item stays in the inventory" do
      state =
        %{
          casting_state(45)
          | pending_item_skill: %{
              skill_id: 29,
              level: 1,
              keep_requirement?: false,
              item_index: 0,
              item_nameid: 601
            }
        }
        |> put_in([Access.key!(:game_state), Access.key!(:inventory)], %{
          0 => %InventoryItem{nameid: 601, amount: 1}
        })

      stub(ItemManagement, :get_item_by_id, fn 601 -> {:ok, %{no_consume: true}} end)
      reject(&InventoryOps.remove/4)

      stub(Interpreter, :begin_item_cast, fn gs, 29, 1, {:unit, 2000}, claim, false ->
        assert {:ok, ^gs} = claim.(gs)
        {:error, :invalid_target, gs, :before_start}
      end)

      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)

      assert {:noreply, committed} = SkillHandler.handle_use_skill(state, 29, 1, 2000)
      assert committed.game_state.inventory[0].amount == 1
    end
  end

  describe "script casts" do
    test "starts an unlearned-rank cast on the player's own unit, tagged for its completion" do
      state = instant_state(100)
      test_pid = self()

      stub(Interpreter, :begin_cast, fn gs, 6, 1, :self, opts ->
        send(test_pid, {:begin, gs, opts})
        {:error, :invalid_target, gs}
      end)

      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_player, fn 1000, _ -> :ok end)

      assert %{game_state: %PlayerState{}} = SkillHandler.start_script_cast(state, 6, 1)
      assert_received {:begin, _gs, opts}
      assert opts[:learned?] == false
      assert opts[:origin] == :script
    end

    test "a gate refusal leaves the state untouched" do
      state = put_in(instant_state(100).game_state.action_state, :dead)
      reject(&Interpreter.begin_cast/5)

      assert ^state = SkillHandler.start_script_cast(state, 6, 1)
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

      stub(Pathfinding, :rewalk_path, fn :map_data, {150, 150}, {151, 150} ->
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
               target: {:unit, 2000}
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
      expect(Pathfinding, :rewalk_path, fn :map_data, {150, 150}, {157, 150} ->
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

    test "an out-of-range skill approaches a dead player target" do
      corpse = %PlayerState{
        character_id: 2_000,
        action_state: :dead,
        stats: %{current_state: %{hp: 0}}
      }

      Mimic.copy(TargetResolver)
      stub(Interpreter, :begin_cast, fn _gs, 29, 1, {:unit, 2_000} -> {:error, :out_of_range} end)
      stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), corpse, :player} end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2_000 -> {:error, :not_found}
        :mob, 2_000 -> {:ok, {160, 150, "prontera"}}
      end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(range: 9)} end)
      stub(MapCache, :get, fn "prontera" -> {:ok, :map_data} end)

      stub(Pathfinding, :rewalk_path, fn :map_data, {150, 150}, {151, 150} ->
        {:ok, [{151, 150}]}
      end)

      test_pid = self()

      stub(MovementHandler, :handle_request_move, fn state, x, y, opts ->
        send(test_pid, {:move, state.game_state, x, y, opts})
        {:noreply, state}
      end)

      assert {:noreply, _} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 2_000)

      assert_received {:move, moving_gs, 151, 150, opts}
      assert Keyword.get(opts, :skill_initiated) == true
      assert moving_gs.action_state == :skill_moving
    end

    test "the walk's end leaves the player idle; the remembered use is tried by its step timer" do
      test_pid = self()

      stub(Interpreter, :walking_attempt, fn _gs, 29, 1, {:unit, 2000} -> :in_range end)

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

      timer = make_ref()

      state = %SessionState{
        connection_pid: self(),
        game_state: moving,
        step_action: step_action(timer, nil)
      }

      assert {:noreply, arrived} = SkillHandler.handle_reached_skill_position(state)
      assert arrived.game_state.action_state == :idle
      refute_received {:redispatch, _skill_id, _level, _target}

      assert {:noreply, retried} = SkillHandler.handle_step_action(arrived, make_ref())
      refute_received {:redispatch, _skill_id, _level, _target}

      assert {:noreply, retried} = SkillHandler.handle_step_action(retried, timer)
      assert_received {:redispatch, 29, 1, {:unit, 2000}}
      assert retried.step_action == nil
    end

    test "a request made while walking toward a target out of reach is remembered" do
      stub(Interpreter, :walking_attempt, fn gs, 29, 1, {:unit, 2000} -> {:step, gs} end)
      reject(&Interpreter.begin_cast/4)
      stub_commit()

      walking = %{
        casting_state(45).game_state
        | action_state: :moving,
          movement_state: :moving,
          walk_path: [{151, 150}]
      }

      state = knowing(%{casting_state(45) | game_state: walking}, 29, 1)

      assert {:noreply, remembered} = SkillHandler.handle_use_skill(state, 29, 1, 2000)
      assert remembered.game_state.movement_state == :moving
      assert %{skill_id: 29, level: 1, target: {:unit, 2000}} = remembered.step_action

      half_stepped = SkillHandler.schedule_step_action(remembered, 0)
      timer = half_stepped.step_action.timer
      assert_receive {:skill, {:step_action, ^timer}}
    end

    test "a remembered use out of range after the walk is dropped without a reply" do
      stub(Interpreter, :walking_attempt, fn gs, 29, 1, {:unit, 2000} ->
        {:error, :out_of_range, gs}
      end)

      reject(&Interpreter.begin_cast/4)
      reject(&MovementHandler.handle_request_move/4)
      stub_commit()
      stub(Broadcast, :to_player, fn _id, packet -> flunk("unexpected #{inspect(packet)}") end)

      timer = make_ref()
      state = %{casting_state(45) | step_action: step_action(timer, nil)}

      assert {:noreply, dropped} = SkillHandler.handle_step_action(state, timer)
      assert dropped.step_action == nil
    end

    test "gives up (no move, stays idle) when no path reaches the target" do
      stub(Interpreter, :begin_cast, fn _gs, 29, 1, {:unit, 2000} -> {:error, :out_of_range} end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {160, 150, "prontera"}}
      end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(range: 9)} end)
      stub(MapCache, :get, fn "prontera" -> {:ok, :map_data} end)

      stub(Pathfinding, :rewalk_path, fn :map_data, {150, 150}, {151, 150} ->
        {:error, :blocked}
      end)

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

      stub(Calculator, :calculate_stats, fn stats, 1000, equipped ->
        send(test_pid, {:recalced, equipped})
        stats
      end)

      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      assert {:noreply, new_state} =
               SkillHandler.handle_use_skill(knowing(base, 46, 1), 46, 1, 2000)

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

    test "an Arrow Vulcan cast holds equipment changes until the cast ends" do
      Mimic.copy(SkillRequest)
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      state = knowing(casting_state(45), 394, 1)
      game_state = state.game_state

      stub(SkillRequest, :targeted, fn _state, 394, 1, 2001, _now ->
        {:use,
         %{
           level: 1,
           target: 2001,
           origin: :normal,
           ends_invincibility?: false,
           clears_item_skill?: false
         }}
      end)

      stub(Interpreter, :begin_cast, fn ^game_state, 394, 1, {:unit, 2001} ->
        {:casting, game_state,
         %{
           skill_id: 394,
           level: 1,
           target: {:unit, 2001},
           element: :neutral,
           fixed: 0,
           total: 5_000
         }}
      end)

      before = now()

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(state, 394, 1, 2001)
      assert new_state.equip_lock_until >= before + 5_000
      assert new_state.equip_lock_until <= now() + 5_000
    end

    test "a cast of another skill leaves equipment changes open" do
      stub(Broadcast, :to_player, fn 1000, %SkillCasting{} -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)
      assert new_state.equip_lock_until == nil
    end

    test "a skill whose cast damage cannot cancel schedules a non-interruptible cast" do
      stub(Broadcast, :to_player, fn 1000, %SkillCasting{} -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)
      {:ok, definition} = Catalog.by_id(29)
      stub(Catalog, :by_id, fn 29 -> {:ok, %{definition | cast_cancel: false}} end)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)

      assert new_state.game_state.state_context.interruptible == false
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
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
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

    test "a script-origin cast completes through the script entry" do
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      assert {:noreply, casting} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)
      token = casting.game_state.state_context.token
      casting = put_in(casting.game_state.casting.origin, :script)
      test_pid = self()

      expect(Interpreter, :complete_script_cast, fn gs, 29, 1, :self ->
        send(test_pid, :script_completed)
        {:ok, gs}
      end)

      reject(&Interpreter.complete_cast/4)

      assert {:noreply, _completed} = SkillHandler.handle_cast_complete(casting, token)
      assert_received :script_completed
    end

    test "a completion failing after its requirement commits the spend and reports the failure" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, %{sp: 27}, _opts -> {:ok, %{}} end)

      assert {:noreply, casting} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)
      token = casting.game_state.state_context.token

      stub(Interpreter, :complete_cast, fn game_state, 29, 1, _target ->
        {:failed, put_in(game_state.stats.current_state.sp, 27), :brew_failed}
      end)

      assert {:noreply, completed} = SkillHandler.handle_cast_complete(casting, token)

      assert completed.game_state.action_state == :idle
      assert completed.game_state.stats.current_state.sp == 27
      assert_received {:to_player, %SkillCastFailed{skill_id: 29}}
    end

    test "a use the reference ends without its effect commits silently" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, %{sp: 27}, _opts -> {:ok, %{}} end)

      assert {:noreply, casting} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)
      token = casting.game_state.state_context.token

      stub(Interpreter, :complete_cast, fn game_state, 29, 1, _target ->
        {:skipped, put_in(game_state.stats.current_state.sp, 27), :target_dead}
      end)

      reject(&CastEnd.complete/3)

      assert {:noreply, completed} = SkillHandler.handle_cast_complete(casting, token)

      assert completed.game_state.action_state == :idle
      assert completed.game_state.stats.current_state.sp == 27
      refute_received {:to_player, %SkillCastFailed{}}
    end

    test "a requirement-only failure reports without the cast-end tail" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, %{sp: 27}, _opts -> {:ok, %{}} end)

      assert {:noreply, casting} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)
      token = casting.game_state.state_context.token

      stub(Interpreter, :complete_cast, fn game_state, 29, 1, _target ->
        {:failed, put_in(game_state.stats.current_state.sp, 27), :skill_not_allowed, :type1_only}
      end)

      reject(&CastEnd.complete/3)

      assert {:noreply, completed} = SkillHandler.handle_cast_complete(casting, token)

      assert completed.game_state.action_state == :idle
      assert completed.game_state.stats.current_state.sp == 27
      assert_received {:to_player, %SkillCastFailed{skill_id: 29}}
    end

    test "an instant use the reference ends without its effect commits silently" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)

      stub(Interpreter, :begin_cast, fn game_state, 29, 1, _target ->
        {:skipped, put_in(game_state.stats.current_state.sp, 27), :target_dead}
      end)

      reject(&CastEnd.complete/3)

      assert {:noreply, completed} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)

      assert completed.game_state.action_state == :idle
      assert completed.game_state.stats.current_state.sp == 27
      refute_received {:to_player, %SkillCastFailed{}}
    end

    test "an instant cast failing after its requirement commits the spend and reports it" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      reject(&Broadcast.to_in_range/6)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, %{sp: 40}, _opts -> {:ok, %{}} end)

      stub(Interpreter, :begin_cast, fn game_state, 12, 1, {:ground, 12, 12} ->
        {:failed, put_in(game_state.stats.current_state.sp, 40), :brew_failed}
      end)

      assert {:noreply, failed} =
               SkillHandler.handle_use_skill_ground(
                 knowing(casting_state(45), 12, 1),
                 12,
                 1,
                 12,
                 12
               )

      assert failed.game_state.stats.current_state.sp == 40
      assert_received {:to_player, %SkillCastFailed{skill_id: 12}}
    end

    test "a cast failing after its requirement still closes the use at its target" do
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      stub(Interpreter, :begin_cast, fn game_state, 12, 1, {:ground, 12, 12} ->
        {:failed, game_state, :brew_failed}
      end)

      expect(CastEnd, :complete, fn %{character_id: 1000}, 12, {:ground, 12, 12} -> :ok end)

      SkillHandler.handle_use_skill_ground(knowing(casting_state(45), 12, 1), 12, 1, 12, 12)
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

    test "damage in the fixed phase cancels the cast too" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      state = interrupting_state(45, fixed_offset: 60_000)

      result = SkillHandler.interrupt_cast_on_damage(state)

      assert result.game_state.action_state == :idle
      assert_received {:to_player, %CastCancel{gid: 1000}}
    end

    test "a non-interruptible cast in the variable phase is immune" do
      reject(&Broadcast.to_player/2)

      state = interrupting_state(45, fixed_offset: -100, interruptible: false)

      assert SkillHandler.interrupt_cast_on_damage(state) == state
    end

    test "bNoCastCancel does not protect a cast on siege ground; bNoCastCancel2 does" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn _map, 150, 150, _range, _packet, _opts -> :ok end)
      map = "cast_cancel_gvg_#{System.unique_integer([:positive])}"
      :ok = MapFlags.set_runtime(map, :gvg, true)
      on_exit(fn -> MapFlags.clear_runtime(map, :gvg) end)

      on_siege_ground = fn modifiers ->
        state =
          45 |> interrupting_state(fixed_offset: -100) |> with_equipment_modifiers(modifiers)

        %{state | game_state: %{state.game_state | map_name: map}}
      end

      protected = on_siege_ground.(%{no_cast_cancel2: 1})
      assert SkillHandler.interrupt_cast_on_damage(protected) == protected

      result = SkillHandler.interrupt_cast_on_damage(on_siege_ground.(%{no_cast_cancel: 1}))
      assert result.game_state.action_state == :idle
      assert_received {:to_player, %CastCancel{gid: 1000}}
    end

    test "bNoCastCancel equipment keeps a variable-phase cast alive despite damage" do
      reject(&Broadcast.to_player/2)

      state =
        45
        |> interrupting_state(fixed_offset: -100)
        |> with_equipment_modifiers(%{no_cast_cancel: 1})

      assert SkillHandler.interrupt_cast_on_damage(state) == state
      assert state.game_state.action_state == :casting
      refute_received {:to_player, %CastCancel{}}
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

    test "interrupt_cast cancels a cast in any phase and clears the descriptor" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      state = interrupting_state(45, fixed_offset: 60_000)
      timer_ref = state.game_state.state_context.timer_ref

      assert {:noreply, result} = SkillHandler.interrupt_cast(state)

      assert result.game_state.casting == nil
      assert result.game_state.action_state == :idle
      assert_received {:to_player, %CastCancel{gid: 1000}}
      assert Process.cancel_timer(timer_ref) == false
    end

    test "interrupt_cast on an idle player is a no-op" do
      reject(&Broadcast.to_player/2)

      state = casting_state(45, :idle)

      assert {:noreply, ^state} = SkillHandler.interrupt_cast(state)
    end

    test "the registry snapshot carries the cast descriptor while casting" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      stub(UnitRegistry, :update_unit_state, fn :player, 1000, snapshot ->
        send(test_pid, {:snapshot, snapshot.casting})
        :ok
      end)

      assert {:noreply, casting} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)
      assert_received {:snapshot, %{skill_id: 29, skill_level: 1}}

      SkillHandler.cancel_cast(casting, :move)
      assert_received {:snapshot, nil}
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

    test "SaCastcancel.begin_attempt/4 rejects :not_casting when no cast is in flight" do
      definition = SaCastcancel.definition()

      assert SaCastcancel.begin_attempt(%PlayerState{casting: nil}, :self, 1, definition) ==
               {:error, :not_casting}

      casting = %PlayerState{casting: %{skill_id: 29}}
      assert SaCastcancel.begin_attempt(casting, :self, 1, definition) == {:ok, casting}
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

  describe "requested skill level" do
    test "a request above the player's level runs at the player's level" do
      expect(Interpreter, :begin_cast, fn _gs, 29, 10, :self -> {:error, :invalid_target} end)

      SkillHandler.handle_use_skill(casting_state(45), 29, 99, 1000)
    end

    test "a request at level 0 runs at level 1" do
      expect(Interpreter, :begin_cast, fn _gs, 29, 1, :self -> {:error, :invalid_target} end)

      SkillHandler.handle_use_skill(casting_state(45), 29, 0, 1000)
    end

    test "a request for a skill the player does not have is dropped without a reply" do
      reject(&Interpreter.begin_cast/4)
      reject(&Broadcast.to_player/2)

      s = casting_state(45)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill(s, 28, 1, 1000)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill_ground(s, 12, 1, 12, 12)
    end

    test "a pending item skill runs at the item's level whatever level was requested" do
      state = %{
        casting_state(45)
        | pending_item_skill: %{
            skill_id: 28,
            level: 3,
            keep_requirement?: false,
            item_index: 0,
            item_nameid: 545
          }
      }

      expect(Interpreter, :begin_item_cast, fn gs, 28, 3, :self, _claim, false ->
        {:error, :invalid_target, gs, :before_start}
      end)

      SkillHandler.handle_use_skill(state, 28, 1, 1000)
    end
  end

  describe "player request decisions" do
    setup do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet, _opts -> :ok end)
      :ok
    end

    test "a refusal sends its notice and leaves the invincibility" do
      stub(MapFlags, :get, fn _map, flag -> flag == :noteleport end)
      reject(&Invincibility.stop/1)
      reject(&Interpreter.begin_cast/4)

      s = knowing(casting_state(45), 26, 1)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill(s, 26, 1, 1000)

      assert_received {:to_player, %SystemNotice{id: :SYSTEM_NOTICE_ID_MAP_CANT_TELEPORT}}
    end

    test "a delay refusal is silent unless @showdelay is on, then reports the interval" do
      reject(&Interpreter.begin_cast/4)
      cooling = put_in(casting_state(45).game_state.skill_cooldowns, %{29 => now() + 60_000})

      SkillHandler.handle_use_skill(cooling, 29, 1, 1000)
      refute_received {:to_player, _packet}

      SkillHandler.handle_use_skill(put_in(cooling.game_state.show_delay, true), 29, 1, 1000)

      assert_received {:to_player,
                       %SkillCastFailed{
                         skill_id: 29,
                         reason: :SKILL_CAST_FAILURE_REASON_ON_COOLDOWN
                       }}
    end

    test "a request that passes ends the invincibility even when it casts nothing" do
      expect(Invincibility, :stop, fn state -> state end)
      reject(&Interpreter.begin_cast/4)

      s = casting_state(45)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill(s, 19, 1, 2000)
    end

    test "a request for another skill clears a pending item skill" do
      expect(Interpreter, :begin_cast, fn gs, 29, 1, :self -> {:error, :invalid_target, gs} end)

      pending = %{
        casting_state(45)
        | pending_item_skill: %{skill_id: 26, level: 1, keep_requirement?: false}
      }

      assert {:noreply, state} = SkillHandler.handle_use_skill(pending, 29, 1, 1000)
      assert state.pending_item_skill == nil
    end

    test "a sitting player's ground request is dropped" do
      reject(&Interpreter.begin_cast/4)

      sitting = knowing(casting_state(45, :sitting), 89, 1)
      assert {:noreply, ^sitting} = SkillHandler.handle_use_skill_ground(sitting, 89, 1, 12, 12)
      refute_received {:to_player, _packet}
    end

    test "a chat-room member's ground request is dropped without ending the invincibility" do
      reject(&Invincibility.stop/1)
      reject(&Interpreter.begin_cast/4)

      s = knowing(casting_state(45), 89, 1)
      s = put_in(s.game_state.waiting_room, 7)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill_ground(s, 89, 1, 12, 12)
      refute_received {:to_player, _packet}
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

      s = knowing(casting_state(45), 12, 1)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill_ground(s, 12, 1, 12, 12)

      assert_received {:to_player,
                       %SkillCastFailed{
                         skill_id: 12,
                         reason: :SKILL_CAST_FAILURE_REASON_MISSING_CATALYST
                       }}
    end

    test "a no_skill player calling handle_use_skill is refused silently and no cast is driven" do
      stub(StatusInterpreter, :can_use_skill?, fn :player, 1000, _skill -> false end)
      reject(&Interpreter.begin_cast/4)

      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      s = casting_state(45)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill(s, 29, 1, 1000)

      assert s.game_state.action_state == :idle
      refute_received {:to_player, _packet}
    end

    test "a no_skill player calling handle_use_skill_ground is refused silently and no cast is driven" do
      stub(StatusInterpreter, :can_use_skill?, fn :player, 1000, _skill -> false end)
      reject(&Interpreter.begin_cast/4)

      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      s = knowing(casting_state(45), 89, 1)
      assert {:noreply, ^s} = SkillHandler.handle_use_skill_ground(s, 89, 1, 12, 12)

      assert s.game_state.action_state == :idle
      refute_received {:to_player, _packet}
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

    test "a status that only forbids starting a cast does not stop its completion" do
      stub(Broadcast, :to_player, fn 1000, _packet -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      assert {:noreply, casting} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)
      token = casting.game_state.state_context.token

      stub(StatusInterpreter, :can_use_skill?, fn :player, 1000, _skill -> false end)
      test_pid = self()

      expect(Interpreter, :complete_cast, fn _game_state, 29, 1, _target ->
        send(test_pid, :completed)
        {:error, :test_stop}
      end)

      assert {:noreply, _completed} = SkillHandler.handle_cast_complete(casting, token)
      assert_received :completed
    end
  end

  describe "a cast ends the attack" do
    setup do
      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {150, 150, "prontera"}}
      end)

      :ok
    end

    test "an instant cast begun while attacking ends the attack and resumes nothing" do
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [], cooldown: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, 1000, _sc, _ -> :ok end)
      stub_commit()
      swing = Process.send_after(self(), {:combat, {:auto_attack, 2000}}, 60_000)

      assert {:noreply, new_state} =
               SkillHandler.handle_use_skill(swinging(instant_state(30), swing), 29, 1, 1000)

      assert new_state.game_state.action_state == :idle
      assert new_state.game_state.combat_target_id == nil
      assert Process.read_timer(swing) == false
      refute_receive {:combat, {:auto_attack, _}}
    end

    test "a timed cast begun while attacking resumes nothing when it completes" do
      stub_commit()
      stub(StatusInterpreter, :apply_status, fn :player, _id, _sc, _ -> :ok end)

      assert {:noreply, casting} =
               SkillHandler.handle_use_skill(locked_attacking_state(45), 29, 1, 2000)

      assert casting.game_state.action_state == :casting
      assert casting.game_state.combat_target_id == nil
      token = casting.game_state.state_context.token

      assert {:noreply, completed} = SkillHandler.handle_cast_complete(casting, token)

      assert completed.game_state.action_state == :idle
      assert completed.game_state.combat_target_id == nil
      assert completed.game_state.continuous_attack_timer == nil
      refute_receive {:combat, {:auto_attack, _}}
    end

    test "a refused cast leaves the attack running" do
      stub_commit()
      swing = Process.send_after(self(), {:combat, {:auto_attack, 2000}}, 60_000)

      assert {:noreply, refused} =
               SkillHandler.handle_use_skill(
                 swinging(locked_attacking_state(0), swing),
                 29,
                 1,
                 2000
               )

      assert refused.game_state.action_state == :attacking
      assert refused.game_state.combat_target_id == 2000
      assert refused.game_state.continuous_attack_timer == swing
      assert is_integer(Process.read_timer(swing))
    end

    test "a combo used while swinging keeps the attack running" do
      stub(UnitRegistry, :unit_exists?, fn :homunculus, _id -> false end)
      stub(Interpreter, :castbegin_passes?, fn _game_state, 272, 1, _target -> true end)
      stub(Catalog, :by_id, fn 272 -> {:ok, definition(id: 272, cast_time: [], cooldown: [])} end)
      stub_commit()

      expect(Interpreter, :begin_cast, fn game_state, 272, 1, {:unit, 2000}, attack_reach: true ->
        {:instant, game_state}
      end)

      swing = Process.send_after(self(), {:combat, {:auto_attack, 2000}}, 60_000)
      state = swinging(locked_attacking_state(100), swing)
      combo = Combo.open(Combo.new(), :quadruple, 9_999_999_999)
      state = %{state | game_state: %{state.game_state | combo: combo}}

      assert {:noreply, comboed} =
               SkillHandler.handle_use_skill(knowing(state, 272, 1), 272, 1, 1000)

      assert comboed.game_state.action_state == :attacking
      assert comboed.game_state.combat_target_id == 2000
      assert comboed.game_state.continuous_attack_timer == swing
      assert is_integer(Process.read_timer(swing))
    end

    test "a swing falling inside a timed combo's cast ends the attack and keeps the cast" do
      swing = Process.send_after(self(), {:combat, {:auto_attack, 2000}}, 60_000)
      casting = begin_timed_combo(swing)

      assert casting.game_state.action_state == :casting
      assert casting.game_state.combat_target_id == 2000
      assert casting.game_state.continuous_attack_timer == swing

      assert {:noreply, swung} = CombatActionHandler.handle_auto_attack(casting, 2000)

      assert swung.game_state.action_state == :casting
      assert swung.game_state.casting.token == casting.game_state.casting.token
      assert swung.game_state.combat_target_id == nil
      assert Process.read_timer(swing) == false

      stub(Interpreter, :complete_cast, fn gs, 272, 1, {:unit, 2000} -> {:ok, gs} end)
      token = swung.game_state.casting.token
      assert {:noreply, completed} = SkillHandler.handle_cast_complete(swung, token)
      assert completed.game_state.action_state == :idle
      refute_receive {:combat, {:auto_attack, _}}
    end

    test "a swing due after a timed combo's cast still comes" do
      swing = Process.send_after(self(), {:combat, {:auto_attack, 2000}}, 60_000)
      casting = begin_timed_combo(swing)

      stub(Interpreter, :complete_cast, fn gs, 272, 1, {:unit, 2000} -> {:ok, gs} end)
      token = casting.game_state.casting.token
      assert {:noreply, completed} = SkillHandler.handle_cast_complete(casting, token)

      assert completed.game_state.action_state == :attacking
      assert completed.game_state.casting == nil
      assert completed.game_state.combat_target_id == 2000
      assert completed.game_state.continuous_attack_timer == swing
      assert is_integer(Process.read_timer(swing))
    end

    test "a combo used while chasing stops the chase and resumes nothing" do
      stub(UnitRegistry, :unit_exists?, fn :homunculus, _id -> false end)
      stub(Interpreter, :castbegin_passes?, fn _game_state, 272, 1, _target -> true end)
      stub(Interpreter, :walking_attempt, fn _gs, 272, 1, {:unit, 2000} -> :in_range end)
      stub(Catalog, :by_id, fn 272 -> {:ok, definition(id: 272, cast_time: [], cooldown: [])} end)
      stub_commit()

      stub(MovementHandler, :handle_force_stop_movement, fn state ->
        {:noreply, %{state | game_state: PlayerState.stop_walking(state.game_state)}}
      end)

      expect(Interpreter, :begin_cast, fn game_state, 272, 1, {:unit, 2000} ->
        {:instant, game_state}
      end)

      state = locked_attacking_state(100)
      combo = Combo.open(Combo.new(), :quadruple, 9_999_999_999)

      chasing = %{
        state.game_state
        | action_state: :combat_moving,
          movement_state: :moving,
          movement_intent: :combat,
          walk_path: [{151, 150}],
          combo: combo
      }

      assert {:noreply, comboed} =
               SkillHandler.handle_use_skill(
                 knowing(%{state | game_state: chasing}, 272, 1),
                 272,
                 1,
                 1000
               )

      assert comboed.game_state.action_state == :idle
      assert comboed.game_state.combat_target_id == nil
      refute_receive {:combat, {:auto_attack, _}}
    end

    test "an out-of-range skill used while attacking ends the attack as its walk begins" do
      stub(Interpreter, :begin_cast, fn _gs, 29, 1, {:unit, 2000} -> {:error, :out_of_range} end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2000 -> {:error, :not_found}
        :mob, 2000 -> {:ok, {160, 150, "prontera"}}
      end)

      stub(Catalog, :by_id, fn 29 -> {:ok, definition(range: 9)} end)
      stub(MapCache, :get, fn "prontera" -> {:ok, :map_data} end)

      stub(Pathfinding, :rewalk_path, fn :map_data, {150, 150}, {151, 150} ->
        {:ok, [{151, 150}]}
      end)

      test_pid = self()

      stub(MovementHandler, :handle_request_move, fn state, x, y, opts ->
        send(test_pid, {:move, state.game_state, x, y, opts})
        {:noreply, state}
      end)

      swing = Process.send_after(self(), {:combat, {:auto_attack, 2000}}, 60_000)
      state = swinging(casting_state(45), swing)

      assert {:noreply, _} = SkillHandler.handle_use_skill(state, 29, 1, 2000)

      assert_received {:move, moving_gs, 151, 150, _opts}
      assert moving_gs.action_state == :skill_moving
      assert moving_gs.combat_target_id == nil
      assert Process.read_timer(swing) == false
    end

    test "a refused input completion leaves the attack running" do
      stub(Interpreter, :complete_cast_with_input, fn _gs, 29, 1, :self, "hi" ->
        {:error, :on_cooldown}
      end)

      stub_commit()
      swing = Process.send_after(self(), {:combat, {:auto_attack, 2000}}, 60_000)
      state = swinging(instant_state(30), swing)

      assert {:noreply, refused} =
               SkillHandler.complete_cast_with_input(state, 29, 1, :self, "hi")

      assert refused.game_state.action_state == :attacking
      assert refused.game_state.combat_target_id == 2000
      assert is_integer(Process.read_timer(swing))
    end

    test "a stop-attacking status during a cast begun while attacking leaves nothing to resume" do
      stub_commit()
      stub(StatusInterpreter, :apply_status, fn :player, _id, _sc, _ -> :ok end)

      assert {:noreply, casting} =
               SkillHandler.handle_use_skill(locked_attacking_state(45), 29, 1, 2000)

      assert {:noreply, poisoned} = CombatActionHandler.handle_stop_attack(casting)
      token = poisoned.game_state.state_context.token

      assert {:noreply, completed} = SkillHandler.handle_cast_complete(poisoned, token)

      assert completed.game_state.action_state == :idle
      assert completed.game_state.combat_target_id == nil
      refute_receive {:combat, {:auto_attack, _}}
    end

    test "an instant cast with no lock does not start an auto-attack loop" do
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [], cooldown: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, 1000, _sc, _ -> :ok end)
      stub_commit()

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(instant_state(30), 29, 1, 1000)

      assert new_state.game_state.combat_target_id == nil
      refute_receive {:combat, {:auto_attack, _}}
    end

    test "a skill that walked into range resumes no attack after casting" do
      stub(Interpreter, :walking_attempt, fn _gs, 29, 1, {:unit, 2000} -> :in_range end)
      stub(Interpreter, :begin_cast, fn gs, 29, 1, {:unit, 2000} -> {:instant, gs} end)
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [], cooldown: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, _id, _sc, _ -> :ok end)
      stub_commit()

      timer = make_ref()

      state = %SessionState{
        connection_pid: self(),
        game_state: casting_state(45).game_state,
        step_action: step_action(timer, 2000)
      }

      assert {:noreply, new_state} = SkillHandler.handle_step_action(state, timer)

      assert new_state.game_state.combat_target_id == nil
      refute_receive {:combat, {:auto_attack, _}}
    end

    test "a damage interrupt of a cast begun while attacking resumes nothing" do
      stub_commit()

      assert {:noreply, casting} =
               SkillHandler.handle_use_skill(locked_attacking_state(45), 29, 1, 2000)

      assert casting.game_state.casting.interruptible
      result = SkillHandler.interrupt_cast_on_damage(casting)

      assert result.game_state.action_state == :idle
      assert result.game_state.combat_target_id == nil
      refute_receive {:combat, {:auto_attack, _}}
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

  defp begin_timed_combo(swing) do
    stub(UnitRegistry, :unit_exists?, fn :homunculus, _id -> false end)
    stub(Interpreter, :castbegin_passes?, fn _game_state, 272, 1, _target -> true end)

    stub(Catalog, :by_id, fn 272 ->
      {:ok, definition(id: 272, cast_time: [1_000], cooldown: [])}
    end)

    stub_commit()

    info = %{
      skill_id: 272,
      level: 1,
      target: {:unit, 2000},
      element: :neutral,
      fixed: 0,
      total: 60_000
    }

    expect(Interpreter, :begin_cast, fn game_state, 272, 1, {:unit, 2000}, attack_reach: true ->
      {:casting, game_state, info}
    end)

    state = swinging(locked_attacking_state(100), swing)
    combo = Combo.open(Combo.new(), :quadruple, 9_999_999_999)
    state = knowing(%{state | game_state: %{state.game_state | combo: combo}}, 272, 1)

    assert {:noreply, casting} = SkillHandler.handle_use_skill(state, 272, 1, 1000)
    casting
  end

  defp swinging(state, swing) do
    game_state = %{
      state.game_state
      | action_state: :attacking,
        combat_target_id: 2000,
        combat_action_type: 7,
        continuous_attack_timer: swing
    }

    %{state | game_state: game_state}
  end

  defp step_action(timer, combat_target_id) do
    %{
      skill_id: 29,
      level: 1,
      target: {:unit, 2000},
      combat_target_id: combat_target_id,
      map_name: "prontera",
      timer: timer
    }
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
    stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
    stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)
  end

  # Builds a real :casting state with a live cast-complete timer and a controllable
  # phase. `fixed_offset` is added to `now`: negative = variable phase (past),
  # positive = fixed phase (future).
  defp with_equipment_modifiers(state, modifiers) do
    stats = state.game_state.stats
    new_stats = %{stats | modifiers: %{stats.modifiers | equipment: modifiers}}
    %{state | game_state: %{state.game_state | stats: new_stats}}
  end

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
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      expect(WarpHandler, :warp, fn session_state, "morocc", 155, 95 ->
        {:ok, session_state}
      end)

      assert {:noreply, new_state} =
               SkillHandler.handle_use_skill(knowing(base, 26, 1), 26, 1, 1000)

      assert Map.get(new_state.game_state, :pending_warp) == nil
    end

    test "pending_warp is cleared even when WarpHandler returns an error" do
      base = instant_state(30)

      staged = %{base.game_state | pending_warp: {"unknown_map", 0, 0}}

      expect(Interpreter, :begin_cast, fn _gs, 26, 1, :self -> {:instant, staged} end)
      stub(Catalog, :by_id, fn 26 -> {:ok, definition(id: 26, cooldown: [])} end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      stub(WarpHandler, :warp, fn _session_state, "unknown_map", 0, 0 ->
        {:error, :map_not_found}
      end)

      assert {:noreply, new_state} =
               SkillHandler.handle_use_skill(knowing(base, 26, 1), 26, 1, 1000)

      assert Map.get(new_state.game_state, :pending_warp) == nil
    end

    test "WarpHandler is not called when pending_warp is nil" do
      stub(Catalog, :by_id, fn 29 -> {:ok, definition(cast_time: [])} end)
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
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
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
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

      assert {:noreply, _new_state} =
               SkillHandler.handle_use_skill(knowing(base, 26, 1), 26, 1, 1000)

      assert_received {:broadcast, "prontera", 150, 150,
                       %SkillEffect{skill_id: 26, level: 1, src_id: 1000, target_id: 1000}}
    end
  end

  describe "no-damage support skills reach clients as SkillEffect" do
    test "AL_CURE broadcasts a SkillEffect on cast" do
      stub(Catalog, :by_id, fn 35 -> {:ok, definition(id: 35, cooldown: [])} end)
      stub(Interpreter, :begin_cast, fn gs, 35, 1, {:unit, 2000} -> {:instant, gs} end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      test_pid = self()

      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, packet ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      assert {:noreply, _} =
               SkillHandler.handle_use_skill(knowing(instant_state(30), 35, 1), 35, 1, 2000)

      assert_received {:broadcast,
                       %SkillEffect{skill_id: 35, level: 1, src_id: 1000, target_id: 2000}}
    end

    test "Brandish Spear, a no-damage cast that sweeps the area, broadcasts no SkillEffect" do
      stub(Catalog, :by_id, fn 57 ->
        {:ok,
         definition(id: 57, target_type: :target_enemy, damage_type: :no_damage, cooldown: [])}
      end)

      stub(Interpreter, :begin_cast, fn gs, 57, 1, {:unit, 2000} -> {:instant, gs} end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      test_pid = self()

      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, packet ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      assert {:noreply, _} =
               SkillHandler.handle_use_skill(knowing(instant_state(30), 57, 1), 57, 1, 2000)

      refute_received {:broadcast, %SkillEffect{}}
    end

    test "Auto Counter's cast ends its stance silently, with no SkillEffect" do
      stub(Catalog, :by_id, fn 61 ->
        {:ok,
         definition(
           id: 61,
           name: :kn_autocounter,
           target_type: :self,
           damage_type: :damage,
           cooldown: []
         )}
      end)

      stub(Interpreter, :begin_cast, fn gs, 61, 1, :self -> {:instant, gs} end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)
      expect(CastEnd, :complete, fn %{character_id: 1000}, 61, :self -> :ok end)

      test_pid = self()

      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, packet ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      assert {:noreply, _} =
               SkillHandler.handle_use_skill(knowing(instant_state(30), 61, 1), 61, 1, 1000)

      refute_received {:broadcast, %SkillEffect{}}
    end

    test "PR_STRECOVERY broadcasts a SkillEffect on cast" do
      stub(Catalog, :by_id, fn 72 -> {:ok, definition(id: 72, cooldown: [])} end)
      stub(Interpreter, :begin_cast, fn gs, 72, 1, {:unit, 2000} -> {:instant, gs} end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)

      test_pid = self()

      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, packet ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      assert {:noreply, _} =
               SkillHandler.handle_use_skill(knowing(instant_state(30), 72, 1), 72, 1, 2000)

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

  defp equip_proc(branch, overrides) do
    Map.merge(
      %{
        branch: branch,
        skill_id: 29,
        level: 1,
        random_level?: false,
        rate: 1_000,
        target: :self,
        entry: :entry
      },
      Map.new(overrides)
    )
  end

  defp definition(fields) do
    struct!(
      %Definition{
        id: 29,
        name: :al_incagi,
        display_name: "Increase AGI",
        max_level: 10,
        sp_cost: [18],
        target_type: :target_ally
      },
      fields
    )
  end

  describe "staged production effects" do
    test "a cast's HP loss lands before its production result" do
      state = casting_state(45)
      hp = state.game_state.stats.current_state.hp

      staged = %{
        state.game_state
        | pending_hp_loss: 10,
          pending_production_result: %{success: false, item_id: 678}
      }

      stub(Interpreter, :begin_cast, fn _game_state, 29, 1, :self -> {:instant, staged} end)
      stub(StatusInterpreter, :on_committed_action, fn :player, 1000, _action -> :unchanged end)
      stub(CharacterPersistence, :update_stats, fn 1000, _fields, _opts -> :ok end)
      stub_commit()

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(state, 29, 1, 1000)
      assert new_state.game_state.stats.current_state.hp == hp - 10
      assert new_state.game_state.pending_hp_loss == nil
      assert new_state.game_state.pending_production_result == nil

      {:messages, messages} = Process.info(self(), :messages)
      hp_left = hp - 10
      hp_param = StatusParams.hp()

      hp_at =
        Enum.find_index(
          messages,
          &match?({:send, _, {:param_change, %{var_id: ^hp_param, value: ^hp_left}}}, &1)
        )

      result_at = Enum.find_index(messages, &match?({:send, _, {:production_result, _}}, &1))

      assert is_integer(hp_at) and is_integer(result_at) and hp_at < result_at
    end
  end

  describe "staged production effects on a failed cast" do
    test "the HP loss, the production result and the failure arrive in that order" do
      state = casting_state(45)
      hp = state.game_state.stats.current_state.hp
      test_pid = self()

      staged = %{
        state.game_state
        | pending_hp_loss: 10,
          pending_production_result: %{success: false, item_id: 678}
      }

      stub(Interpreter, :begin_cast, fn _game_state, 29, 1, :self ->
        {:failed, staged, :stuff_insufficient}
      end)

      stub(StatusInterpreter, :on_committed_action, fn :player, 1000, _action -> :unchanged end)
      stub(CharacterPersistence, :update_stats, fn 1000, _fields, _opts -> :ok end)
      stub_commit()

      stub(Broadcast, :to_player, fn 1000, packet ->
        send(test_pid, {:to_player, packet})
        :ok
      end)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(state, 29, 1, 1000)
      assert new_state.game_state.stats.current_state.hp == hp - 10

      {:messages, messages} = Process.info(self(), :messages)
      hp_left = hp - 10
      hp_param = StatusParams.hp()

      hp_at =
        Enum.find_index(
          messages,
          &match?({:send, _, {:param_change, %{var_id: ^hp_param, value: ^hp_left}}}, &1)
        )

      result_at = Enum.find_index(messages, &match?({:send, _, {:production_result, _}}, &1))

      failure_at =
        Enum.find_index(
          messages,
          &match?(
            {:to_player, %SkillCastFailed{reason: :SKILL_CAST_FAILURE_REASON_STUFF_INSUFFICIENT}},
            &1
          )
        )

      assert is_integer(hp_at) and is_integer(result_at) and is_integer(failure_at)
      assert hp_at < result_at and result_at < failure_at
    end
  end

  describe "staged HP loss" do
    test "a loss of every remaining HP kills the player" do
      state = casting_state(45)
      staged = %{state.game_state | pending_hp_loss: state.game_state.stats.current_state.hp}

      stub(Interpreter, :begin_cast, fn _game_state, 29, 1, :self -> {:instant, staged} end)
      stub(StatusInterpreter, :on_committed_action, fn :player, 1000, _action -> :unchanged end)
      stub(CharacterPersistence, :update_stats, fn 1000, _fields, _opts -> :ok end)
      stub_commit()

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(state, 29, 1, 1000)
      assert new_state.game_state.stats.current_state.hp == 0
      assert new_state.game_state.action_state == :dead
    end
  end

  describe "open menu snapshot" do
    # Autospell's menu is the one a skill request may be made under.
    test "a cast sees the open skill menu's source skill" do
      state = %{
        casting_state(45)
        | pending_skill_menu: %{skill_id: 279, kind: :ITEMS, entry_ids: [], level: 1}
      }

      assert_menu_seen(state, 279)
    end

    test "a cast with no open menu sees 0" do
      assert_menu_seen(casting_state(45), 0)
    end
  end

  defp assert_menu_seen(state, expected) do
    test_pid = self()

    stub(Interpreter, :begin_cast, fn game_state, 29, 1, :self ->
      send(test_pid, {:open_menu, game_state.open_menu_skill_id})
      {:error, :invalid_target}
    end)

    stub(Broadcast, :to_player, fn 1000, %SkillCastFailed{} -> :ok end)

    SkillHandler.handle_use_skill(state, 29, 1, 1000)
    assert_received {:open_menu, ^expected}
  end

  describe "logout window" do
    test "a cast that begins opens it" do
      stub(Broadcast, :to_player, fn 1000, %SkillCasting{} -> :ok end)
      stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet, _opts -> :ok end)

      assert {:noreply, new_state} = SkillHandler.handle_use_skill(casting_state(45), 29, 1, 1000)

      assert new_state.game_state.action_state == :casting
      assert is_integer(new_state.canlog_at)
    end

    test "a refused ground cast leaves it closed" do
      stub(Interpreter, :begin_cast, fn _game_state, 264, 1, {:ground, 152, 150} ->
        {:error, :invalid_target}
      end)

      assert {:noreply, returned} =
               SkillHandler.handle_use_skill_ground(snap_state(), 264, 1, 152, 150)

      assert returned.canlog_at == nil
    end
  end

  describe "report_cast_failure/3 with a text line" do
    test "sends the line to the caster, then the failure" do
      test_pid = self()

      stub(Broadcast, :to_player, fn 1000, packet ->
        send(test_pid, {:to_player, packet})
        :ok
      end)

      reply = {:message, "You can't open a shop on this map", {:fail, :failed}}
      SkillHandler.report_cast_failure(41, 1000, {:not_ok, reply})

      assert_received {:to_player,
                       %Aesir.Net.ChatMessage{
                         gid: 1000,
                         message: "You can't open a shop on this map"
                       }}

      assert_received {:to_player, %Aesir.Net.SkillCastFailed{skill_id: 41}}
    end
  end
end
