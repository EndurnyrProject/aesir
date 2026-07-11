defmodule Aesir.ZoneServer.Unit.Player.Handlers.HealthHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  @moduletag :capture_log

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.CastCancel
  alias Aesir.Net.ParamChange
  alias Aesir.Net.Resurrect
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # SP_HP param id / SP_BASE_EXP / SP_JOB_EXP
  @sp_hp 5
  @sp_base_exp 1
  @sp_job_exp 2

  setup :set_mimic_from_context

  setup do
    Mimic.copy(CharacterPersistence)
    Mimic.copy(MovementHandler)
    Mimic.copy(StatusInterpreter)
    Mimic.copy(ModifierCalculator)
    Mimic.copy(Config)
    Mimic.copy(Leveling)

    stub(StatusInterpreter, :on_damage, fn _, _, _ -> :ok end)
    stub(UnitRegistry, :update_unit_state, fn _, _, _ -> :ok end)
    stub(ModifierCalculator, :get_all_modifiers, fn :player, _ -> %{} end)
    stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
    stub(CharacterPersistence, :update_character, fn _, _, _ -> {:ok, %Character{}} end)
    stub(SpatialIndex, :remove_player, fn _ -> :ok end)
    stub(SpatialIndex, :clear_visibility, fn _ -> :ok end)
    stub(SpatialIndex, :add_player, fn _, _, _, _ -> :ok end)
    stub(MovementHandler, :handle_visibility_update, fn game_state -> game_state end)

    :ok
  end

  describe "damaged_hp/2" do
    test "subtracts damage and clamps at 0" do
      assert HealthHandler.damaged_hp(100, 30) == 70
      assert HealthHandler.damaged_hp(20, 50) == 0
    end
  end

  describe "apply_damage/3" do
    test "reduces HP and pushes an SP_HP update when the player survives" do
      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_damage(30, 2001, build_state(100, :idle))

      assert game_state.stats.current_state.hp == 70
      assert game_state.action_state == :idle
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: @sp_hp, value: 70}}}
    end

    test "invokes status on_damage with post-damage HP populated" do
      test_pid = self()

      stub(StatusInterpreter, :on_damage, fn :player, char_id, damage_info ->
        send(test_pid, {:on_damage_called, char_id, damage_info})
        :ok
      end)

      HealthHandler.apply_damage(30, 2001, build_state(100, :idle))

      assert_received {:on_damage_called, 1, damage_info}
      assert damage_info.damage == 30
      assert damage_info.hp_after == 70
      assert damage_info.max_hp == 100
    end

    test "kills the player and marks them dead when HP reaches 0" do
      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_damage(150, 2001, build_state(100, :idle))

      assert game_state.stats.current_state.hp == 0
      assert game_state.action_state == :dead
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: @sp_hp, value: 0}}}
    end

    test "ignores damage on an already dead player" do
      state = build_state(0, :dead)

      assert {:noreply, ^state} = HealthHandler.apply_damage(50, 2001, state)
      refute_received {:send_packet, _}
    end

    test "ignores non-positive damage" do
      state = build_state(100, :idle)

      assert {:noreply, ^state} = HealthHandler.apply_damage(0, 2001, state)
    end

    test "interrupts a survivable cast in the variable phase" do
      test_pid = self()
      stub(Broadcast, :to_player, fn 1, packet -> send(test_pid, {:to_player, packet}) end)
      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet, _opts -> :ok end)

      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_damage(30, 2001, casting_state(-100))

      assert game_state.action_state == :idle
      assert_received {:to_player, %CastCancel{gid: 1}}
    end

    test "does not interrupt a survivable cast in the fixed phase" do
      reject(&Broadcast.to_player/2)

      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_damage(30, 2001, casting_state(60_000))

      assert game_state.action_state == :casting
      refute_received {:to_player, %CastCancel{}}
    end
  end

  describe "apply_heal/3" do
    test "raises HP and pushes an SP_HP update" do
      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_heal(20, nil, build_state(70, :idle))

      assert game_state.stats.current_state.hp == 90
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: @sp_hp, value: 90}}}
    end

    test "clamps HP at max_hp" do
      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_heal(30, nil, build_state(90, :idle))

      assert game_state.stats.current_state.hp == 100
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: @sp_hp, value: 100}}}
    end

    test "is a no-op when the player is dead" do
      state = build_state(0, :dead)

      assert {:noreply, ^state} = HealthHandler.apply_heal(50, nil, state)
      refute_received {:send, _, _}
    end

    test "is a no-op when amount is zero or negative" do
      state = build_state(70, :idle)

      assert {:noreply, ^state} = HealthHandler.apply_heal(0, nil, state)
      assert {:noreply, ^state} = HealthHandler.apply_heal(-10, nil, state)
    end

    test "does not trigger death or cast interrupt" do
      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_heal(20, nil, build_state(50, :idle))

      assert game_state.action_state == :idle
      assert game_state.stats.current_state.hp == 70
    end

    test "scales the heal by the target's received_heal_rate (once)" do
      stub(ModifierCalculator, :get_all_modifiers, fn :player, 1 ->
        %{received_heal_rate: 50}
      end)

      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_heal(20, nil, build_state(50, :idle))

      assert game_state.stats.current_state.hp == 80
    end

    test "leaves the heal unchanged with no received_heal_rate" do
      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_heal(20, nil, build_state(50, :idle))

      assert game_state.stats.current_state.hp == 70
    end

    test "persists the updated HP asynchronously" do
      expect(CharacterPersistence, :update_stats, fn 1, %{hp: 90}, [async: true] ->
        {:ok, %Character{}}
      end)

      HealthHandler.apply_heal(20, nil, build_state(70, :idle))
    end
  end

  describe "death EXP penalty" do
    test "subtracts the computed base/job loss, pushes the exp params and persists" do
      stub(Leveling, :death_penalty, fn _prog, 1, 1 -> {10, 5} end)

      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_damage(
          150,
          2001,
          build_state(100, :idle, %{base_exp: 100, job_exp: 40})
        )

      assert game_state.action_state == :dead
      assert game_state.stats.progression.base_exp == 90
      assert game_state.stats.progression.job_exp == 35
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: @sp_base_exp, value: 90}}}
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: @sp_job_exp, value: 35}}}
    end

    test "persists the reduced exp to the character row" do
      stub(Leveling, :death_penalty, fn _prog, _b, _j -> {10, 5} end)

      expect(CharacterPersistence, :update_character, fn 1,
                                                         %{base_exp: 90, job_exp: 35},
                                                         [async: true] ->
        {:ok, %Character{}}
      end)

      HealthHandler.apply_damage(
        150,
        2001,
        build_state(100, :idle, %{base_exp: 100, job_exp: 40})
      )
    end

    test "skips entirely when the config rate is 0" do
      stub(Config, :death_penalty_base, fn -> 0 end)
      stub(Config, :death_penalty_job, fn -> 0 end)
      reject(&Leveling.death_penalty/3)
      reject(&CharacterPersistence.update_character/3)

      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_damage(
          150,
          2001,
          build_state(100, :idle, %{base_exp: 100, job_exp: 40})
        )

      assert game_state.stats.progression.base_exp == 100
      assert game_state.stats.progression.job_exp == 40
    end

    test "skips when the dying player carries no_death_penalty" do
      stub(ModifierCalculator, :get_all_modifiers, fn :player, _ -> %{no_death_penalty: 1} end)
      reject(&Leveling.death_penalty/3)
      reject(&CharacterPersistence.update_character/3)

      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_damage(
          150,
          2001,
          build_state(100, :idle, %{base_exp: 100, job_exp: 40})
        )

      assert game_state.stats.progression.base_exp == 100
      assert game_state.stats.progression.job_exp == 40
    end

    test "does not persist when the computed loss is zero" do
      stub(Leveling, :death_penalty, fn _prog, _b, _j -> {0, 0} end)
      reject(&CharacterPersistence.update_character/3)

      {:noreply, %{game_state: game_state}} =
        HealthHandler.apply_damage(
          150,
          2001,
          build_state(100, :idle, %{base_exp: 100, job_exp: 40})
        )

      assert game_state.stats.progression.base_exp == 100
      assert game_state.stats.progression.job_exp == 40
    end
  end

  describe "handle_restart/2" do
    test "revives a dead player at full HP/SP and warps them to their save point" do
      stub(WarpHandler, :warp, fn warp_state, save_map, save_x, save_y ->
        send(self(), {:warp_called, save_map, save_x, save_y})
        {:ok, warp_state}
      end)

      {:noreply, %{game_state: game_state}} =
        HealthHandler.handle_restart(0, build_state(0, :dead))

      assert game_state.action_state == :idle
      assert game_state.stats.current_state.hp == 100
      assert game_state.stats.current_state.sp == 50
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: @sp_hp, value: 100}}}
      assert_received {:warp_called, "save_map", 60, 70}
      refute_received {:send, _res_channel, {_res_tag, %Resurrect{}}}
    end

    test "falls back to resurrecting in place when the save-point warp fails" do
      stub(WarpHandler, :warp, fn _state, _map, _x, _y -> {:error, :map_not_found} end)

      {:noreply, %{game_state: game_state}} =
        HealthHandler.handle_restart(0, build_state(0, :dead))

      assert game_state.action_state == :idle
      assert game_state.stats.current_state.hp == 100
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: @sp_hp, value: 100}}}
      assert_received {:send, _res_channel, {_res_tag, %Resurrect{gid: 1}}}
    end

    test "does nothing when respawn is requested by a living player" do
      state = build_state(100, :idle)

      assert {:noreply, ^state} = HealthHandler.handle_restart(0, state)
    end

    test "disconnects the session on char-select (type 1)" do
      state = build_state(100, :idle)

      assert {:stop, :normal, ^state} = HealthHandler.handle_restart(1, state)
    end
  end

  # A live :casting state whose phase is driven by `fixed_offset`: negative =
  # variable phase, positive = fixed phase.
  defp casting_state(fixed_offset) do
    state = build_state(100, :idle)
    now = System.monotonic_time(:millisecond)
    token = make_ref()
    timer_ref = Process.send_after(self(), {:cast_complete, token}, 60_000)

    context = %{
      skill_id: 14,
      skill_level: 10,
      target: :self,
      element: :water,
      started_at: now,
      fixed_until: now + fixed_offset,
      total_until: now + 60_000,
      timer_ref: timer_ref,
      token: token,
      interruptible: true
    }

    {:ok, casting} = PlayerState.transition_to(state.game_state, :casting, context)
    %{state | game_state: casting}
  end

  defp build_state(hp, action_state, progression_attrs \\ %{}) do
    progression =
      struct(
        PlayerProgression,
        Map.merge(
          %{base_level: 1, job_level: 1, base_exp: 0, job_exp: 0, job_id: 0},
          progression_attrs
        )
      )

    stats = %Stats{
      current_state: %CurrentState{hp: hp, sp: 10},
      derived_stats: %DerivedStats{max_hp: 100, max_sp: 50, aspd: 150},
      progression: progression
    }

    game_state = %PlayerState{
      character_id: 1,
      account_id: 100,
      action_state: action_state,
      x: 50,
      y: 50,
      map_name: "prontera",
      save_map: "save_map",
      save_x: 60,
      save_y: 70,
      visible_players: MapSet.new(),
      stats: stats
    }

    %{
      game_state: game_state,
      connection_pid: self()
    }
  end
end
