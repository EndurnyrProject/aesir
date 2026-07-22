defmodule Aesir.ZoneServer.Unit.Session.AdapterTest do
  @moduledoc """
  Contract tests for the two `Unit.Session.Adapter` implementations.

  The adapters are dumb per-type accessors: `get_vitals`/`put_vitals` are pure
  reads/writes (clamp math lives in `Unit.Session.Vitals`, not here), while
  `notify_vitals`, `set_position` and `commit` are the per-type side-effect
  seams, smoke-tested through the modules they delegate to.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.ParamChange
  alias Aesir.Net.UnitHp
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.SessionAdapter, as: MobAdapter
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionAdapter, as: PlayerAdapter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  describe "get_vitals/1" do
    test "player reads hp/sp from current_state and max from derived_stats" do
      state = player_state(hp: 42, sp: 17, max_hp: 250, max_sp: 90)

      assert PlayerAdapter.get_vitals(state) == %{hp: 42, sp: 17, max_hp: 250, max_sp: 90}
    end

    test "mob reads hp/sp/max straight off the state" do
      state = mob_state(hp: 42, sp: 17, max_hp: 250, max_sp: 90)

      assert MobAdapter.get_vitals(state) == %{hp: 42, sp: 17, max_hp: 250, max_sp: 90}
    end
  end

  describe "put_vitals/2 (round-trips with get_vitals/1)" do
    test "player writes hp and sp, leaves maxima untouched" do
      state = player_state(hp: 100, sp: 50, max_hp: 250, max_sp: 90)

      written = PlayerAdapter.put_vitals(state, %{hp: 30, sp: 5})

      assert PlayerAdapter.get_vitals(written) == %{hp: 30, sp: 5, max_hp: 250, max_sp: 90}
    end

    test "player partial update touches only the given field" do
      state = player_state(hp: 100, sp: 50, max_hp: 250, max_sp: 90)

      written = PlayerAdapter.put_vitals(state, %{sp: 7})

      assert PlayerAdapter.get_vitals(written) == %{hp: 100, sp: 7, max_hp: 250, max_sp: 90}
    end

    test "mob writes hp and sp, leaves maxima untouched" do
      state = mob_state(hp: 100, sp: 50, max_hp: 250, max_sp: 90)

      written = MobAdapter.put_vitals(state, %{hp: 30, sp: 5})

      assert MobAdapter.get_vitals(written) == %{hp: 30, sp: 5, max_hp: 250, max_sp: 90}
    end

    test "mob partial update touches only the given field" do
      state = mob_state(hp: 100, sp: 50, max_hp: 250, max_sp: 90)

      written = MobAdapter.put_vitals(state, %{hp: 30})

      assert MobAdapter.get_vitals(written) == %{hp: 30, sp: 50, max_hp: 250, max_sp: 90}
    end
  end

  describe "notify_vitals/1" do
    test "player pushes SP_HP and SP_SP ParamChanges to its own connection" do
      state = player_state(hp: 30, sp: 5, max_hp: 250, max_sp: 90)

      assert :ok = PlayerAdapter.notify_vitals(state)

      hp_id = StatusParams.hp()
      sp_id = StatusParams.sp()
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: ^hp_id, value: 30}}}
      assert_received {:send, _channel, {_tag, %ParamChange{var_id: ^sp_id, value: 5}}}
    end

    test "mob broadcasts a UnitHp to nearby players" do
      state = mob_state(hp: 30, sp: 5, max_hp: 250, max_sp: 90)
      test_pid = self()

      expect(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, packet ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      assert :ok = MobAdapter.notify_vitals(state)
      assert_received {:broadcast, %UnitHp{id: 9001, hp: 30, max_hp: 250}}
    end
  end

  describe "set_position/2" do
    test "player writes the cell and publishes it through Movement" do
      state = player_state(hp: 100, sp: 50, max_hp: 250, max_sp: 90)
      test_pid = self()

      expect(Movement, :set_position, fn :player, 1, published, "prontera" ->
        send(test_pid, {:published, published.x, published.y})
        :ok
      end)

      moved = PlayerAdapter.set_position(state, {160, 170})

      assert {moved.game_state.x, moved.game_state.y} == {160, 170}
      assert_received {:published, 160, 170}
    end

    test "mob writes the cell and publishes it through Movement" do
      state = mob_state(hp: 100, sp: 50, max_hp: 250, max_sp: 90)
      test_pid = self()

      expect(Movement, :set_position, fn :mob, 9001, published, "prontera" ->
        send(test_pid, {:published, published.x, published.y})
        :ok
      end)

      moved = MobAdapter.set_position(state, {160, 170})

      assert {moved.x, moved.y} == {160, 170}
      assert_received {:published, 160, 170}
    end
  end

  describe "stop_movement/1" do
    test "player clears the walk path and movement state" do
      state = player_state(hp: 100, sp: 50, max_hp: 250, max_sp: 90)
      moving = put_in(state.game_state.movement_state, :moving)
      moving = put_in(moving.game_state.walk_path, [{1, 1}, {2, 2}])

      stopped = PlayerAdapter.stop_movement(moving)

      assert stopped.game_state.movement_state == :standing
      assert stopped.game_state.walk_path == []
    end

    test "mob clears the walk path and movement state" do
      state = %{
        mob_state(hp: 100, sp: 50, max_hp: 250, max_sp: 90)
        | movement_state: :moving,
          walk_path: [{1, 1}]
      }

      stopped = MobAdapter.stop_movement(state)

      assert stopped.movement_state == :standing
      assert stopped.walk_path == []
    end
  end

  describe "commit/2" do
    test "player refreshes the registry snapshot and persists hp/sp" do
      prev = player_state(hp: 100, sp: 50, max_hp: 250, max_sp: 90)
      updated = PlayerAdapter.put_vitals(prev, %{hp: 30, sp: 5})
      test_pid = self()

      expect(UnitRegistry, :update_unit_state, fn :player, 1, committed ->
        send(
          test_pid,
          {:registry, committed.stats.current_state.hp, committed.stats.current_state.sp}
        )

        :ok
      end)

      expect(CharacterPersistence, :update_stats, fn 1, stats, opts ->
        send(test_pid, {:persist, stats, opts})
        :ok
      end)

      committed = PlayerAdapter.commit(prev, updated)

      assert PlayerAdapter.get_vitals(committed) == %{hp: 30, sp: 5, max_hp: 250, max_sp: 90}
      assert_received {:registry, 30, 5}
      assert_received {:persist, %{hp: 30, sp: 5}, [async: true]}
    end

    test "mob refreshes its registry snapshot and returns the updated state" do
      prev = mob_state(hp: 100, sp: 50, max_hp: 250, max_sp: 90)
      updated = MobAdapter.put_vitals(prev, %{hp: 30})
      test_pid = self()

      expect(UnitRegistry, :update_unit_state, fn :mob, 9001, committed ->
        send(test_pid, {:registry, committed.hp})
        :ok
      end)

      assert MobAdapter.commit(prev, updated) == updated
      assert_received {:registry, 30}
    end
  end

  # Builders -----------------------------------------------------------------

  defp player_state(overrides) do
    game_state = PlayerState.new(character())
    stats = game_state.stats

    current_state = %{
      stats.current_state
      | hp: Keyword.fetch!(overrides, :hp),
        sp: Keyword.fetch!(overrides, :sp)
    }

    derived_stats = %{
      stats.derived_stats
      | max_hp: Keyword.fetch!(overrides, :max_hp),
        max_sp: Keyword.fetch!(overrides, :max_sp)
    }

    game_state = %{
      game_state
      | stats: %{stats | current_state: current_state, derived_stats: derived_stats}
    }

    %{game_state: game_state, connection_pid: self()}
  end

  defp character do
    %Character{
      id: 1,
      account_id: 100,
      name: "Adapter",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      class: 0,
      base_level: 50,
      job_level: 50,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 7
    }
  end

  defp mob_state(overrides) do
    %MobState{
      instance_id: 9001,
      mob_id: 1002,
      mob_data: mob_definition(),
      spawn_ref: mob_spawn(),
      x: 150,
      y: 150,
      map_name: "prontera",
      hp: Keyword.fetch!(overrides, :hp),
      max_hp: Keyword.fetch!(overrides, :max_hp),
      sp: Keyword.fetch!(overrides, :sp),
      max_sp: Keyword.fetch!(overrides, :max_sp),
      spawned_at: System.system_time(:second)
    }
  end

  defp mob_definition do
    %MobDefinition{
      id: 1002,
      aegis_name: "PORING",
      name: "Poring",
      level: 1,
      hp: 100,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 6, luk: 5},
      attack_range: 1,
      size: :medium,
      race: :plant,
      element: {:water, 1},
      walk_speed: 400,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400
    }
  end

  defp mob_spawn do
    %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: 150, y: 150, xs: 0, ys: 0}
    }
  end
end
