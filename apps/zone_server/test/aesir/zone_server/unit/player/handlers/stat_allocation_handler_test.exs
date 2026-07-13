defmodule Aesir.ZoneServer.Unit.Player.Handlers.StatAllocationHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.StatUpResult
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatAllocationHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # dragon_knight (trait/4th job) vs rune_knight (classic 3rd job)
  @trait_job 4252
  @classic_job 4054

  setup :verify_on_exit!

  setup do
    Mimic.copy(MessageRouter)
    test_pid = self()

    stub(Stats, :calculate_stats, fn stats, _char_id -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, _id, _gs -> :ok end)
    stub(CharacterPersistence, :update_character, fn _id, _attrs, async: true -> {:ok, %{}} end)
    stub(StatusSync, :send_stat_updates, fn _pid, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _pid, params -> send(test_pid, {:params, params}) end)
    stub(MessageRouter, :send_to, fn _pid, msg -> send(test_pid, {:ack, msg}) end)
    :ok
  end

  defp state(class, base_overrides, prog_overrides) do
    base = PlayerState.new(character(class))
    base_stats = struct(base.stats.base_stats, base_overrides)

    progression =
      struct(base.stats.progression, Keyword.put(prog_overrides, :job_id, class))

    stats = %{base.stats | base_stats: base_stats, progression: progression}
    game_state = %{base | character_id: 1000, stats: stats}
    %{connection_pid: self(), game_state: game_state}
  end

  defp character(class) do
    %Aesir.Commons.Models.Character{
      id: 1000,
      account_id: 2000,
      name: "Trait",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      pow: 0,
      sta: 0,
      wis: 0,
      spl: 0,
      con: 0,
      crt: 0,
      status_point: 0,
      trait_point: 0,
      base_level: 210,
      job_level: 70,
      class: class
    }
  end

  describe "trait-stat allocation" do
    test "raising POW spends exactly 1 trait point and raises pow by 1" do
      state = state(@trait_job, [pow: 10], trait_point: 5)

      {:noreply, new_state} =
        StatAllocationHandler.handle_status_up(StatusParams.pow(), 1, state)

      assert new_state.game_state.stats.base_stats.pow == 11
      assert new_state.game_state.stats.progression.trait_point == 4
    end

    test "acks ok and pushes the upow cost indicator with value 1" do
      StatAllocationHandler.handle_status_up(
        StatusParams.pow(),
        1,
        state(@trait_job, [pow: 10], trait_point: 5)
      )

      pow_id = StatusParams.pow()
      assert_received {:ack, %StatUpResult{stat_id: ^pow_id, ok: true, value: 11}}

      upow = StatusParams.upow()
      trait_point = StatusParams.trait_point()
      assert_received {:params, %{^upow => 1, ^trait_point => 4}}
    end

    test "persists the stat, the trait-point balance, and vitals" do
      test_pid = self()

      stub(CharacterPersistence, :update_character, fn 1000, attrs, async: true ->
        send(test_pid, {:persisted, attrs})
        {:ok, %{}}
      end)

      {:noreply, new_state} =
        StatAllocationHandler.handle_status_up(
          StatusParams.pow(),
          1,
          state(@trait_job, [pow: 10], trait_point: 5)
        )

      stats = new_state.game_state.stats
      assert_received {:persisted, attrs}

      assert attrs == %{
               pow: 11,
               trait_point: 4,
               hp: stats.current_state.hp,
               max_hp: stats.derived_stats.max_hp,
               sp: stats.current_state.sp,
               max_sp: stats.derived_stats.max_sp,
               ap: stats.current_state.ap,
               max_ap: stats.derived_stats.max_ap
             }
    end

    test "cannot raise a trait stat past the cap of 100" do
      state = state(@trait_job, [pow: 100], trait_point: 5)

      {:noreply, new_state} =
        StatAllocationHandler.handle_status_up(StatusParams.pow(), 1, state)

      assert new_state == state
      pow_id = StatusParams.pow()
      assert_received {:ack, %StatUpResult{stat_id: ^pow_id, ok: false, value: 100}}
    end

    test "an amount larger than the pool spends only what is available" do
      state = state(@trait_job, [pow: 10], trait_point: 3)

      {:noreply, new_state} =
        StatAllocationHandler.handle_status_up(StatusParams.pow(), 10, state)

      assert new_state.game_state.stats.base_stats.pow == 13
      assert new_state.game_state.stats.progression.trait_point == 0
    end

    test "a non-trait job cannot allocate trait stats and state is untouched" do
      state = state(@classic_job, [pow: 0], trait_point: 0)

      {:noreply, new_state} =
        StatAllocationHandler.handle_status_up(StatusParams.pow(), 1, state)

      assert new_state == state
      pow_id = StatusParams.pow()
      assert_received {:ack, %StatUpResult{stat_id: ^pow_id, ok: false, value: 0}}
    end
  end

  describe "classic-stat allocation on a trait job" do
    test "STR can be raised toward the 135 cap with the renewal scaling cost" do
      state = state(@trait_job, [str: 130], status_point: 999)

      {:noreply, new_state} =
        StatAllocationHandler.handle_status_up(StatusParams.str(), 1, state)

      assert new_state.game_state.stats.base_stats.str == 131
      assert new_state.game_state.stats.progression.status_point < 999
    end

    test "publishes recalculated maxima and post-clamp current resources" do
      test_pid = self()
      state = state(@trait_job, [vit: 10], status_point: 999)

      stats = %{
        state.game_state.stats
        | current_state: struct(state.game_state.stats.current_state, hp: 500, sp: 400, ap: 300)
      }

      game_state = %{state.game_state | party_id: 7, stats: stats}
      state = %{state | game_state: game_state}

      stub(Stats, :calculate_stats, fn recalculated, 1000 ->
        derived = struct(recalculated.derived_stats, max_hp: 250, max_sp: 200, max_ap: 100)
        %{recalculated | derived_stats: derived}
      end)

      expect(Manager, :sync_member, fn 7, 1000, member ->
        assert %Member{
                 hp: 250,
                 max_hp: 250,
                 sp: 200,
                 max_sp: 200,
                 ap: 100,
                 max_ap: 100
               } = member

        {:ok, %{}}
      end)

      stub(CharacterPersistence, :update_character, fn 1000, attrs, async: true ->
        send(test_pid, {:persisted, attrs})
        {:ok, %{}}
      end)

      assert {:noreply, new_state} =
               StatAllocationHandler.handle_status_up(StatusParams.vit(), 1, state)

      assert new_state.game_state.stats.current_state.hp == 250
      assert new_state.game_state.stats.current_state.sp == 200
      assert new_state.game_state.stats.current_state.ap == 100

      stats = new_state.game_state.stats
      assert_received {:persisted, attrs}

      assert attrs == %{
               vit: 11,
               status_point: stats.progression.status_point,
               hp: 250,
               max_hp: 250,
               sp: 200,
               max_sp: 200,
               ap: 100,
               max_ap: 100
             }
    end
  end
end
