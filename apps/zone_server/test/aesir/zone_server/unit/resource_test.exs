defmodule Aesir.ZoneServer.Unit.ResourceTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Resource
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @unit_id 1_001

  setup :verify_on_exit!

  setup do
    Mimic.copy(UnitRegistry)
    Mimic.copy(PlayerSession)
    Mimic.copy(MobSession)
    :ok
  end

  describe "drain_sp_percent/3" do
    test "drains a player's maximum SP with fractional amounts truncated" do
      player = player(max_sp: 101)

      stub(UnitRegistry, :get_unit, fn :player, @unit_id ->
        {:ok, {PlayerState, player, self()}}
      end)

      for {percentage, expected} <- [{20, 20}, {35, 35}, {50, 50}, {65, 65}, {80, 80}] do
        expect(PlayerSession, :consume_sp, fn pid, ^expected ->
          assert pid == self()
          :ok
        end)

        assert Resource.drain_sp_percent(:player, @unit_id, percentage) == :ok
      end
    end

    test "drains a mob's maximum SP through its owning session" do
      mob = mob(max_sp: 101)
      stub(UnitRegistry, :get_unit, fn :mob, @unit_id -> {:ok, {MobState, mob, self()}} end)

      expect(MobSession, :zap_sp, fn pid, 35 ->
        assert pid == self()
        :ok
      end)

      assert Resource.drain_sp_percent(:mob, @unit_id, 35) == :ok
    end

    test "does nothing for missing or dead units" do
      dead_player = player(action_state: :dead, hp: 0, max_sp: 100)
      dead_mob = mob(is_dead: true, hp: 0, max_sp: 100)

      stub(UnitRegistry, :get_unit, fn
        :player, 1 -> {:error, :not_found}
        :player, 2 -> {:ok, {PlayerState, dead_player, self()}}
        :mob, 3 -> {:ok, {MobState, dead_mob, self()}}
      end)

      reject(&PlayerSession.consume_sp/2)
      reject(&MobSession.zap_sp/2)

      assert Resource.drain_sp_percent(:player, 1, 20) == :ok
      assert Resource.drain_sp_percent(:player, 2, 20) == :ok
      assert Resource.drain_sp_percent(:mob, 3, 20) == :ok
    end

    test "does not drain players with invalid maximum SP" do
      invalid_values = [nil, -1, 1.5]

      stub(UnitRegistry, :get_unit, fn :player, unit_id ->
        max_sp = Enum.at(invalid_values, unit_id - 1)
        {:ok, {PlayerState, player(max_sp: max_sp), self()}}
      end)

      stub(PlayerSession, :consume_sp, fn pid, amount ->
        assert pid == self()
        assert amount == 0
        :ok
      end)

      for unit_id <- 1..length(invalid_values) do
        assert Resource.drain_sp_percent(:player, unit_id, 20) == :ok
      end
    end

    test "does not drain mobs with invalid maximum SP" do
      invalid_values = [nil, -1, 1.5]

      stub(UnitRegistry, :get_unit, fn :mob, unit_id ->
        max_sp = Enum.at(invalid_values, unit_id - 1)
        {:ok, {MobState, mob(max_sp: max_sp), self()}}
      end)

      stub(MobSession, :zap_sp, fn pid, amount ->
        assert pid == self()
        assert amount == 0
        :ok
      end)

      for unit_id <- 1..length(invalid_values) do
        assert Resource.drain_sp_percent(:mob, unit_id, 20) == :ok
      end
    end
  end

  describe "drain_sp/3" do
    test "drains a fixed amount from live players and mobs" do
      player = player(max_sp: 100)
      mob = mob(max_sp: 100)

      stub(UnitRegistry, :get_unit, fn
        :player, 1 -> {:ok, {PlayerState, player, self()}}
        :mob, 2 -> {:ok, {MobState, mob, self()}}
      end)

      expect(PlayerSession, :consume_sp, fn pid, 12 ->
        assert pid == self()
        :ok
      end)

      expect(MobSession, :zap_sp, fn pid, 20 ->
        assert pid == self()
        :ok
      end)

      assert :ok = Resource.drain_sp(:player, 1, 12)
      assert :ok = Resource.drain_sp(:mob, 2, 20)
    end
  end

  defp player(opts) do
    stats = %Stats{
      current_state: %CurrentState{hp: Keyword.get(opts, :hp, 100), sp: 1},
      derived_stats: %DerivedStats{max_sp: Keyword.fetch!(opts, :max_sp)}
    }

    %PlayerState{action_state: Keyword.get(opts, :action_state, :idle), stats: stats}
  end

  defp mob(opts) do
    max_sp = Keyword.fetch!(opts, :max_sp)

    state =
      MobState.new(
        @unit_id,
        %MobDefinition{
          id: 1001,
          aegis_name: "test_mob",
          name: "Test Mob",
          level: 25,
          hp: 100,
          sp: max_sp,
          stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
          atk: 50,
          matk: 60,
          def: 25,
          mdef: 10,
          attack_range: 1,
          walk_speed: 200,
          attack_delay: 1200,
          attack_motion: 500,
          client_attack_motion: 400,
          damage_motion: 300,
          element: {:neutral, 1},
          race: :formless,
          size: :medium
        },
        %MobSpawn{
          mob: 1001,
          amount: 1,
          respawn_time: 5000,
          spawn_area: %SpawnArea{x: 100, y: 100}
        },
        "prontera",
        100,
        100
      )

    %{state | hp: Keyword.get(opts, :hp, 100), is_dead: Keyword.get(opts, :is_dead, false)}
  end
end
