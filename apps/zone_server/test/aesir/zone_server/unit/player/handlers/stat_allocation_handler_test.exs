defmodule Aesir.ZoneServer.Unit.Player.Handlers.StatAllocationHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.StatUpResult
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatAllocationHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @trait_job 4252
  @classic_job 1

  setup :set_mimic_private
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
    %Character{
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
      base_level: if(class == @trait_job, do: 210, else: 99),
      job_level: if(class == @trait_job, do: 70, else: 50),
      class: class
    }
  end

  describe "trait-stat allocation" do
    @tag game_mode: :pre_renewal
    test "pre-renewal refuses POW without entering the trait success path" do
      state = state(@classic_job, [pow: 10], trait_point: 5)
      stats_binary = :erlang.term_to_binary(state.game_state.stats)

      reject(&Mechanics.stat_cost/0)
      reject(&Stats.calculate_stats/2)
      reject(&UnitRegistry.update_unit_state/3)
      reject(&CharacterPersistence.update_character/3)
      reject(&StatusSync.send_params/2)
      reject(&StatusSync.send_stat_updates/2)

      assert {:noreply, new_state} =
               StatAllocationHandler.handle_status_up(StatusParams.pow(), 1, state)

      assert new_state === state
      assert :erlang.term_to_binary(new_state.game_state.stats) === stats_binary

      pow_id = StatusParams.pow()
      assert_received {:ack, %StatUpResult{stat_id: ^pow_id, ok: false, value: 10}}
    end

    @tag game_mode: :renewal
    test "renewal POW allocation spends exactly 1 trait point and raises pow by 1" do
      state = state(@trait_job, [pow: 10], trait_point: 5)

      {:noreply, new_state} =
        StatAllocationHandler.handle_status_up(StatusParams.pow(), 1, state)

      assert new_state.game_state.stats.base_stats.pow == 11
      assert new_state.game_state.stats.progression.trait_point == 4
    end

    @tag game_mode: :renewal
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

    @tag game_mode: :renewal
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

    @tag game_mode: :renewal
    test "the last trait increase spends one point and clears its next-cost indicator" do
      state = state(@trait_job, [pow: 99], trait_point: 5)

      assert {:noreply, result} =
               StatAllocationHandler.handle_status_up(StatusParams.pow(), 1, state)

      assert result.game_state.stats.base_stats.pow == 100
      assert result.game_state.stats.progression.trait_point == 4
      upow = StatusParams.upow()
      assert_received {:params, %{^upow => 0}}
    end

    @tag game_mode: :renewal
    test "cannot raise a trait stat past the cap of 100" do
      state = state(@trait_job, [pow: 100], trait_point: 5)

      {:noreply, new_state} =
        StatAllocationHandler.handle_status_up(StatusParams.pow(), 1, state)

      assert new_state == state
      pow_id = StatusParams.pow()
      assert_received {:ack, %StatUpResult{stat_id: ^pow_id, ok: false, value: 100}}
    end

    @tag game_mode: :renewal
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

  describe "primary-stat allocation" do
    test "shared primary allocation respects the cap and spends the exact cost" do
      state = state(@classic_job, [str: 98], status_point: 100)

      assert {:noreply, result} =
               StatAllocationHandler.handle_status_up(StatusParams.str(), 10, state)

      assert result.game_state.stats.base_stats.str == 99
      assert result.game_state.stats.progression.status_point == 89
      str_id = StatusParams.str()
      assert_received {:ack, %StatUpResult{stat_id: ^str_id, ok: true, value: 99}}
      ustr = StatusParams.ustr()
      assert_received {:params, %{^ustr => 0}}
    end

    test "shared bulk allocation stops before an unaffordable point" do
      state = state(@classic_job, [str: 9], status_point: 6)

      assert {:noreply, result} =
               StatAllocationHandler.handle_status_up(StatusParams.str(), 10, state)

      assert result.game_state.stats.base_stats.str == 11
      assert result.game_state.stats.progression.status_point == 2
    end

    test "capped and unaffordable primary requests have no success side effects" do
      states = [
        state(@classic_job, [str: 99], status_point: 100),
        state(@classic_job, [str: 5], status_point: 1)
      ]

      reject(&Stats.calculate_stats/2)
      reject(&UnitRegistry.update_unit_state/3)
      reject(&CharacterPersistence.update_character/3)
      reject(&StatusSync.send_params/2)
      reject(&StatusSync.send_stat_updates/2)

      for state <- states do
        assert {:noreply, ^state} =
                 StatAllocationHandler.handle_status_up(StatusParams.str(), 1, state)

        value = state.game_state.stats.base_stats.str
        str_id = StatusParams.str()
        assert_received {:ack, %StatUpResult{stat_id: ^str_id, ok: false, value: ^value}}
      end
    end

    @tag game_mode: :renewal
    test "STR can be raised toward the 135 cap with the renewal scaling cost" do
      state = state(@trait_job, [str: 130], status_point: 999)

      {:noreply, new_state} =
        StatAllocationHandler.handle_status_up(StatusParams.str(), 1, state)

      assert new_state.game_state.stats.base_stats.str == 131
      assert new_state.game_state.stats.progression.status_point == 959
    end

    test "publishes recalculated maxima and post-clamp current resources" do
      test_pid = self()

      {job, max_ap} =
        %{renewal: {@trait_job, 100}, pre_renewal: {@classic_job, 0}}[GameMode.mode()]

      state = state(job, [vit: 10], status_point: 999)

      stats = %{
        state.game_state.stats
        | current_state: struct(state.game_state.stats.current_state, hp: 500, sp: 400, ap: 300)
      }

      game_state = %{state.game_state | party_id: 7, stats: stats}
      state = %{state | game_state: game_state}

      stub(Stats, :calculate_stats, fn recalculated, 1000 ->
        derived = struct(recalculated.derived_stats, max_hp: 250, max_sp: 200, max_ap: max_ap)
        %{recalculated | derived_stats: derived}
      end)

      expect(Manager, :sync_member, fn 7, 1000, member ->
        assert %Member{
                 hp: 250,
                 max_hp: 250,
                 sp: 200,
                 max_sp: 200,
                 ap: ^max_ap,
                 max_ap: ^max_ap
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
      assert new_state.game_state.stats.current_state.ap == max_ap

      stats = new_state.game_state.stats
      assert_received {:persisted, attrs}

      assert attrs == %{
               vit: 11,
               status_point: stats.progression.status_point,
               hp: 250,
               max_hp: 250,
               sp: 200,
               max_sp: 200,
               ap: max_ap,
               max_ap: max_ap
             }
    end
  end
end
