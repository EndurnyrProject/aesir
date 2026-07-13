defmodule Aesir.ZoneServer.Unit.Player.Handlers.StatsManagerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context

  test "base stat updates publish recalculated current and maximum resources" do
    state = state()
    recalculated = recalculated_stats(state.game_state.stats)

    expect(Stats, :calculate_stats, fn stats, 1000 ->
      assert stats.base_stats.str == 20
      recalculated
    end)

    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _game_state -> :ok end)

    expect(Manager, :sync_member, fn 7, 1000, member ->
      assert_member_resources(member)
      {:ok, %{}}
    end)

    assert {:reply, :ok, %{game_state: %{stats: ^recalculated}}} =
             StatsManager.handle_update_base_stat(:str, 20, state)
  end

  test "synchronous recalculation publishes current and maximum resources" do
    state = state()
    recalculated = recalculated_stats(state.game_state.stats)

    expect(Stats, :calculate_stats, fn stats, 1000 ->
      assert stats == state.game_state.stats
      recalculated
    end)

    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _game_state -> :ok end)

    expect(Manager, :sync_member, fn 7, 1000, member ->
      assert_member_resources(member)
      {:ok, %{}}
    end)

    assert {:reply, ^recalculated, %{game_state: %{stats: ^recalculated}}} =
             StatsManager.handle_sync_recalculate_stats(state)
  end

  defp state do
    game_state = PlayerState.new(character())
    %{connection_pid: self(), game_state: %{game_state | party_id: 7}}
  end

  defp recalculated_stats(stats) do
    stats
    |> put_in([Access.key!(:current_state), Access.key!(:hp)], 700)
    |> put_in([Access.key!(:current_state), Access.key!(:sp)], 250)
    |> put_in([Access.key!(:current_state), Access.key!(:ap)], 20)
    |> put_in([Access.key!(:derived_stats), Access.key!(:max_hp)], 700)
    |> put_in([Access.key!(:derived_stats), Access.key!(:max_sp)], 250)
    |> put_in([Access.key!(:derived_stats), Access.key!(:max_ap)], 20)
  end

  defp assert_member_resources(member) do
    assert member == %Member{
             char_id: 1000,
             name: "Stat Tester",
             job_id: 0,
             base_level: 1,
             hp: 700,
             max_hp: 700,
             sp: 250,
             max_sp: 250,
             ap: 20,
             max_ap: 20,
             online: true,
             map_name: "prontera"
           }
  end

  defp character do
    %Character{
      id: 1000,
      account_id: 2000,
      name: "Stat Tester",
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
      base_level: 1,
      job_level: 1,
      class: 0
    }
  end
end
