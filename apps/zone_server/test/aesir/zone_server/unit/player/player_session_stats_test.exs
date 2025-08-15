defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionStatsTest do
  use ExUnit.Case, async: false

  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Events
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :verify_on_exit!
  setup :set_mimic_global

  setup do
    stub(Events.Player, :subscribe_to_map, fn _ -> :ok end)
    stub(Events.Player, :broadcast_spawn, fn _, _ -> :ok end)
    stub(Events.Player, :broadcast_despawn, fn _, _ -> :ok end)
    stub(Events.Movement, :subscribe_to_cells, fn _, _ -> :ok end)
    stub(Events.Movement, :unsubscribe_from_cells, fn _, _ -> :ok end)
    stub(SpatialIndex, :update_position, fn _, _, _, _ -> :ok end)
    stub(SpatialIndex, :remove_player, fn _ -> :ok end)

    if :ets.info(:zone_players) == :undefined do
      :ets.new(:zone_players, [:set, :public, :named_table])
    end

    on_exit(fn ->
      if :ets.info(:zone_players) != :undefined do
        :ets.delete_all_objects(:zone_players)
      end
    end)

    :ok
  end

  describe "Stats API integration" do
    setup do
      character = %Character{
        id: 12_345,
        account_id: 67_890,
        name: "TestPlayer",
        last_map: "prontera",
        last_x: 155,
        last_y: 183,
        str: 25,
        agi: 30,
        vit: 35,
        int: 40,
        dex: 20,
        luk: 15,
        base_level: 50,
        job_level: 30,
        base_exp: 1000,
        job_exp: 500,
        hp: 800,
        sp: 300,
        skill_point: 10
      }

      connection_pid =
        spawn(fn ->
          Process.flag(:trap_exit, true)

          receive do
            :shutdown ->
              :ok

            _ ->
              receive do
                :shutdown -> :ok
                _ -> :ok
              end
          end
        end)

      {:ok, pid} = PlayerSession.start_link(character: character, connection_pid: connection_pid)

      :sys.get_state(pid)

      %{character: character, session_pid: pid, connection_pid: connection_pid}
    end

    test "get_current_stats/1 returns initialized stats", %{
      session_pid: pid,
      character: character
    } do
      stats = PlayerSession.get_current_stats(pid)

      assert %Stats{} = stats
      assert stats.base_stats.str == character.str
      assert stats.base_stats.agi == character.agi
      assert stats.base_stats.vit == character.vit
      assert stats.base_stats.int == character.int
      assert stats.base_stats.dex == character.dex
      assert stats.base_stats.luk == character.luk

      assert stats.progression.base_level == character.base_level
      assert stats.progression.job_level == character.job_level
      assert stats.progression.base_exp == character.base_exp
      assert stats.progression.job_exp == character.job_exp

      assert stats.current_state.hp == character.hp
      assert stats.current_state.sp == character.sp

      # Derived stats should be calculated
      assert stats.derived_stats.max_hp > 0
      assert stats.derived_stats.max_sp > 0
    end

    test "update_base_stat/3 updates stat and recalculates derived stats", %{session_pid: pid} do
      initial_stats = PlayerSession.get_current_stats(pid)
      initial_max_hp = initial_stats.derived_stats.max_hp

      # Update VIT which affects max HP
      assert :ok = PlayerSession.update_base_stat(pid, :vit, 60)

      # Verify the stat was updated and derived stats recalculated
      updated_stats = PlayerSession.get_current_stats(pid)
      assert updated_stats.base_stats.vit == 60
      assert updated_stats.derived_stats.max_hp > initial_max_hp

      # Other stats should remain unchanged
      assert updated_stats.base_stats.str == initial_stats.base_stats.str
      assert updated_stats.base_stats.agi == initial_stats.base_stats.agi
      assert updated_stats.base_stats.int == initial_stats.base_stats.int
      assert updated_stats.base_stats.dex == initial_stats.base_stats.dex
      assert updated_stats.base_stats.luk == initial_stats.base_stats.luk
    end

    test "update_base_stat/3 validates stat names", %{session_pid: pid} do
      assert :ok = PlayerSession.update_base_stat(pid, :str, 50)
      assert :ok = PlayerSession.update_base_stat(pid, :agi, 50)
      assert :ok = PlayerSession.update_base_stat(pid, :vit, 50)
      assert :ok = PlayerSession.update_base_stat(pid, :int, 50)
      assert :ok = PlayerSession.update_base_stat(pid, :dex, 50)
      assert :ok = PlayerSession.update_base_stat(pid, :luk, 50)

      assert_raise FunctionClauseError, fn ->
        PlayerSession.update_base_stat(pid, :invalid_stat, 50)
      end

      assert_raise FunctionClauseError, fn ->
        PlayerSession.update_base_stat(pid, :max_hp, 1000)
      end
    end

    test "recalculate_stats/1 recalculates and returns updated stats", %{session_pid: pid} do
      initial_stats = PlayerSession.get_current_stats(pid)

      # Manually modify stats by updating VIT first
      PlayerSession.update_base_stat(pid, :vit, 80)

      # Recalculate should return the updated stats
      recalculated_stats = PlayerSession.recalculate_stats(pid)

      assert %Stats{} = recalculated_stats
      assert recalculated_stats.base_stats.vit == 80
      assert recalculated_stats.derived_stats.max_hp > initial_stats.derived_stats.max_hp

      # Verify the session's internal state was also updated
      current_stats = PlayerSession.get_current_stats(pid)
      assert current_stats == recalculated_stats
    end

    test "INT changes affect max SP correctly", %{session_pid: pid} do
      initial_stats = PlayerSession.get_current_stats(pid)
      initial_max_sp = initial_stats.derived_stats.max_sp

      # Update INT which affects max SP
      PlayerSession.update_base_stat(pid, :int, 80)

      updated_stats = PlayerSession.get_current_stats(pid)
      assert updated_stats.base_stats.int == 80
      assert updated_stats.derived_stats.max_sp > initial_max_sp
    end

    test "multiple stat updates work correctly", %{session_pid: pid} do
      PlayerSession.update_base_stat(pid, :str, 99)
      PlayerSession.update_base_stat(pid, :agi, 99)
      PlayerSession.update_base_stat(pid, :vit, 99)
      PlayerSession.update_base_stat(pid, :int, 99)
      PlayerSession.update_base_stat(pid, :dex, 99)
      PlayerSession.update_base_stat(pid, :luk, 99)

      final_stats = PlayerSession.get_current_stats(pid)

      assert final_stats.base_stats.str == 99
      assert final_stats.base_stats.agi == 99
      assert final_stats.base_stats.vit == 99
      assert final_stats.base_stats.int == 99
      assert final_stats.base_stats.dex == 99
      assert final_stats.base_stats.luk == 99

      # Level 50: base_hp = 35 + 50*5 = 285, with VIT=99: 285 * (1.0 + 99*0.01) = 285 * 1.99 = 567.15 -> 567
      assert final_stats.derived_stats.max_hp > 500

      # Level 50: base_sp = 10 + 50*2 = 110, with INT=99: 110 * (1.0 + 99*0.01) = 110 * 1.99 = 218.9 -> 218
      assert final_stats.derived_stats.max_sp > 200
    end
  end

  describe "Stats initialization during PlayerSession startup" do
    test "stats are properly initialized from character data during init" do
      character = %Character{
        id: 98_765,
        account_id: 11_111,
        name: "InitTestPlayer",
        last_map: "geffen",
        last_x: 120,
        last_y: 100,
        str: 45,
        agi: 50,
        vit: 40,
        int: 60,
        dex: 35,
        luk: 25,
        base_level: 75,
        job_level: 50,
        base_exp: 3000,
        job_exp: 2000,
        hp: 1500,
        sp: 800,
        skill_point: 15
      }

      connection_pid =
        spawn(fn ->
          receive do
            _ -> :ok
          end
        end)

      {:ok, pid} = PlayerSession.start_link(character: character, connection_pid: connection_pid)

      state = PlayerSession.get_state(pid)
      assert %Stats{} = state.game_state.stats

      stats = state.game_state.stats
      assert stats.base_stats.str == 45
      assert stats.base_stats.agi == 50
      assert stats.base_stats.vit == 40
      assert stats.base_stats.int == 60
      assert stats.base_stats.dex == 35
      assert stats.base_stats.luk == 25

      assert stats.progression.base_level == 75
      assert stats.progression.job_level == 50

      # Verify derived stats were calculated correctly
      # 410
      expected_base_hp = 35 + 75 * 5
      # 410 * 1.4 = 574
      expected_max_hp = trunc(expected_base_hp * (1.0 + 40 * 0.01))
      assert stats.derived_stats.max_hp == expected_max_hp

      expected_base_sp = 10 + 75 * 2
      expected_max_sp = trunc(expected_base_sp * (1.0 + 60 * 0.01))

      assert stats.derived_stats.max_sp == expected_max_sp
    end
  end

  describe "Stats persistence and state management" do
    setup do
      character = %Character{
        id: 55_555,
        account_id: 77_777,
        name: "StateTestPlayer",
        last_map: "payon",
        last_x: 100,
        last_y: 100,
        str: 20,
        agi: 25,
        vit: 30,
        int: 35,
        dex: 15,
        luk: 10,
        base_level: 40,
        job_level: 25,
        base_exp: 800,
        job_exp: 400,
        hp: 600,
        sp: 200,
        skill_point: 5
      }

      connection_pid =
        spawn(fn ->
          receive do
            _ -> :ok
          end
        end)

      {:ok, pid} = PlayerSession.start_link(character: character, connection_pid: connection_pid)

      %{character: character, session_pid: pid}
    end

    test "stats remain consistent during session lifecycle", %{
      session_pid: pid,
      character: character
    } do
      initial_stats = PlayerSession.get_current_stats(pid)

      assert initial_stats.base_stats.str == character.str
      assert initial_stats.progression.base_level == character.base_level

      PlayerSession.update_base_stat(pid, :str, 30)
      PlayerSession.update_base_stat(pid, :int, 45)

      updated_stats = PlayerSession.get_current_stats(pid)

      assert updated_stats.base_stats.str == 30
      assert updated_stats.base_stats.int == 45

      assert updated_stats.base_stats.agi == character.agi
      assert updated_stats.base_stats.vit == character.vit
      assert updated_stats.base_stats.dex == character.dex
      assert updated_stats.base_stats.luk == character.luk

      # Verify derived stats were recalculated
      assert updated_stats.derived_stats.max_sp > initial_stats.derived_stats.max_sp
    end

    test "recalculate_stats preserves base stats while updating derived stats", %{
      session_pid: pid
    } do
      PlayerSession.update_base_stat(pid, :vit, 70)
      PlayerSession.update_base_stat(pid, :int, 80)

      after_update_stats = PlayerSession.get_current_stats(pid)

      # Force recalculation
      recalc_stats = PlayerSession.recalculate_stats(pid)

      assert recalc_stats.base_stats.vit == 70
      assert recalc_stats.base_stats.int == 80
      assert recalc_stats.base_stats == after_update_stats.base_stats

      # Derived stats should be recalculated (should be the same since no modifiers changed)
      assert recalc_stats.derived_stats.max_hp == after_update_stats.derived_stats.max_hp
      assert recalc_stats.derived_stats.max_sp == after_update_stats.derived_stats.max_sp
    end
  end
end
