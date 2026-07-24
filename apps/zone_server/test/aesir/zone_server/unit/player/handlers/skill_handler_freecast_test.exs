defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillHandlerFreecastTest do
  @moduledoc """
  The cast lifecycle once Free Cast overlays a cast on another action state.

  `SkillHandlerTest` pins the same lifecycle for a standing (non-Free-Cast)
  caster, where the cast owns `action_state`; these cover the overlaid cast,
  which must resolve identically from `:moving`.
  """
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Net.CastCancel
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @freecast_id 278
  @increase_agi_id 29

  setup :verify_on_exit!

  setup do
    stub(StatusInterpreter, :can_use_skill?, fn _type, _id, _skill -> true end)
    stub(Broadcast, :to_player, fn _, _ -> :ok end)
    stub(Broadcast, :to_in_range, fn _, _, _, _, _, _ -> :ok end)
    :ok
  end

  describe "a cast overlaid on a walking Free Caster" do
    test "fires mid-walk against the target it was started with" do
      test_pid = self()
      stub(PlayerStats, :calculate_stats, fn stats, _id, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, _id, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn _id, _attrs, _opts -> {:ok, %{}} end)

      stub(Interpreter, :complete_cast, fn game_state, skill_id, level, target ->
        send(test_pid, {:completed, skill_id, level, target})
        {:ok, game_state}
      end)

      state = walking_cast_state()
      token = state.game_state.casting.token

      assert {:noreply, completed} = SkillHandler.handle_cast_complete(state, token)

      assert_received {:completed, @increase_agi_id, 1, {:unit, 2000}}
      assert completed.game_state.casting == nil
    end

    test "leaves the player walking rather than dropping them to idle" do
      stub(PlayerStats, :calculate_stats, fn stats, _id, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, _id, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn _id, _attrs, _opts -> {:ok, %{}} end)
      stub(Interpreter, :complete_cast, fn game_state, _id, _lv, _target -> {:ok, game_state} end)

      state = walking_cast_state()
      token = state.game_state.casting.token

      assert {:noreply, completed} = SkillHandler.handle_cast_complete(state, token)

      assert completed.game_state.casting == nil
      assert completed.game_state.action_state == :moving
      assert completed.game_state.movement_state == :moving
      assert completed.game_state.walk_path == [{51, 50}]
    end

    test "a cast that resolves after the walk ended returns the player to idle" do
      stub(PlayerStats, :calculate_stats, fn stats, _id, _equipped -> stats end)
      stub(UnitRegistry, :update_unit_state, fn :player, _id, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(CharacterPersistence, :update_character, fn _id, _attrs, _opts -> {:ok, %{}} end)
      stub(Interpreter, :complete_cast, fn game_state, _id, _lv, _target -> {:ok, game_state} end)

      # Arrival: `handle_movement_tick/1` stops the walk and `PlayerSession`
      # transitions :moving -> :idle, with the cast still in flight.
      state = walking_cast_state()
      stopped = PlayerState.stop_walking(state.game_state)
      {:ok, arrived} = PlayerState.transition_to(stopped, :idle)
      token = arrived.casting.token

      assert {:noreply, completed} =
               SkillHandler.handle_cast_complete(%{state | game_state: arrived}, token)

      assert completed.game_state.action_state == :idle
      assert completed.game_state.casting == nil
    end

    test "a stale token never resolves an overlaid cast" do
      reject(&Interpreter.complete_cast/4)

      state = walking_cast_state()

      assert {:noreply, unchanged} = SkillHandler.handle_cast_complete(state, make_ref())
      assert unchanged == state
    end
  end

  describe "damage interruption of an overlaid cast" do
    test "damage in the variable phase cancels it mid-walk" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1000, packet -> send(test_pid, {:to_player, packet}) end)

      state = walking_cast_state(fixed_offset: -100)

      result = SkillHandler.interrupt_cast_on_damage(state)

      assert result.game_state.casting == nil
      assert_received {:to_player, %CastCancel{gid: 1000}}
    end

    test "damage in the fixed phase leaves it running mid-walk" do
      state = walking_cast_state(fixed_offset: 60_000)

      assert SkillHandler.interrupt_cast_on_damage(state) == state
    end

    test "a non-interruptible overlaid cast in the variable phase is immune" do
      state = walking_cast_state(fixed_offset: -100, interruptible: false)

      assert SkillHandler.interrupt_cast_on_damage(state) == state
    end
  end

  # `transition_to(state, :casting)` with a default context leaves `casting` an
  # empty map. Nothing in production does that, but the cast reads no longer gate
  # on `action_state: :casting` — only on the descriptor — so a malformed one must
  # not be mistaken for a real cast and crash on a missing key.
  describe "a malformed cast descriptor" do
    test "is not interruptible" do
      state = %{game_state: %{casting: %{}}, connection_pid: self()}

      assert SkillHandler.interrupt_cast_on_damage(state) == state
    end

    test "is not cancellable" do
      state = %{game_state: %{casting: %{}}, connection_pid: self()}

      assert SkillHandler.cancel_cast(state, :move) == state
    end

    test "never resolves a cast" do
      reject(&Interpreter.complete_cast/4)

      state = %{game_state: %{casting: %{}}, connection_pid: self()}

      assert {:noreply, ^state} = SkillHandler.handle_cast_complete(state, make_ref())
    end
  end

  describe "cast stacking" do
    test "a new cast is refused while an overlaid cast is in flight" do
      reject(&Interpreter.begin_cast/4)

      state = walking_cast_state()

      assert {:noreply, unchanged} =
               SkillHandler.handle_use_skill(state, @increase_agi_id, 1, 1000)

      assert unchanged.game_state.casting == state.game_state.casting
    end
  end

  # A Free Caster walking with a cast overlaid: `action_state: :moving` with the
  # `casting` descriptor still set — the state Free Cast creates.
  defp walking_cast_state(opts \\ []) do
    base = PlayerState.new(character())

    stats =
      put_in(base.stats, [Access.key!(:progression), Access.key!(:learned_skills)], %{
        @increase_agi_id => 10,
        @freecast_id => 5
      })

    now = System.monotonic_time(:millisecond)
    token = make_ref()
    timer_ref = Process.send_after(self(), {:cast_complete, token}, 60_000)

    context = %{
      skill_id: @increase_agi_id,
      skill_level: 1,
      target: {:unit, 2000},
      element: :neutral,
      started_at: now,
      fixed_until: now + Keyword.get(opts, :fixed_offset, 60_000),
      total_until: now + 60_000,
      timer_ref: timer_ref,
      token: token,
      interruptible: Keyword.get(opts, :interruptible, true),
      combat_target_id: nil
    }

    {:ok, casting} = PlayerState.transition_to(%{base | stats: stats}, :casting, context)
    {:ok, moving} = PlayerState.transition_to(casting, :moving)

    game_state = %{moving | walk_path: [{51, 50}], movement_state: :moving}

    %SessionState{game_state: game_state, connection_pid: self()}
  end

  defp character do
    %Aesir.Commons.Models.Character{
      id: 1000,
      account_id: 2000,
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
      sp: 45,
      max_sp: 45,
      status_point: 0,
      skill_point: 0
    }
  end
end
