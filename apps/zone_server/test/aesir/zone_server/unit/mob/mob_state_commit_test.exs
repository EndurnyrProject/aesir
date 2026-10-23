defmodule Aesir.ZoneServer.Unit.Mob.StateCommitTest do
  @moduledoc """
  Every mob vital mutation must republish the registry snapshot, since combat
  targeting (`Unit.living?`), AoI snapshots (`hp_pct`) and owner counts read
  the registry rather than messaging the mob. Movement used to be the only
  publisher, so a stationary mob's HP went stale.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup {Aesir.MimicMode, :global}
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Coordinator, :mob_died, fn _map, _id, _owner -> :ok end)
    :ok
  end

  test "damage republishes HP without the mob moving" do
    pid = start_registered_mob(hp: 500, sp: 50)

    MobSession.apply_damage(pid, 200, nil)
    _ = MobSession.get_state(pid)

    assert registry_state().hp == 300
  end

  test "a lethal hit republishes the dead snapshot so living?/1 fails closed" do
    pid = start_registered_mob(hp: 10, sp: 50)

    MobSession.apply_damage(pid, 10, nil)
    _ = MobSession.get_state(pid)

    snapshot = registry_state()
    assert snapshot.is_dead
    refute Unit.living?(snapshot)
  end

  test "death ends the statuses death ends; the mob's removal ends the rest" do
    pid = start_registered_mob(hp: 10, sp: 50)
    :ok = StatusStorage.apply_status(:mob, 1, :sc_blessing, val1: 5, duration: 60_000)
    :ok = StatusStorage.apply_status(:mob, 1, :sc_endure, val1: 1, duration: 60_000)

    MobSession.apply_damage(pid, 10, nil)
    _ = MobSession.get_state(pid)

    refute StatusStorage.has_status?(:mob, 1, :sc_blessing)
    assert StatusStorage.has_status?(:mob, 1, :sc_endure)

    :ok = GenServer.stop(pid)

    assert StatusStorage.get_unit_statuses(:mob, 1) == []
  end

  test "a successful mug republishes the coin-stolen flip" do
    pid = start_registered_mob(hp: 500, sp: 50)

    assert {:ok, zeny} =
             MobSession.attempt_mug(pid, %{dex: 200, luk: 200, base_level: 500}, 10)

    assert zeny > 0
    assert registry_state().coin_stolen
  end

  test "a failed mug leaves the published state untouched" do
    pid = start_registered_mob(hp: 500, sp: 50)

    assert {:error, :no_coin} =
             MobSession.attempt_mug(pid, %{dex: 0, luk: 0, base_level: 1}, 1)

    refute registry_state().coin_stolen
  end

  test "heal republishes" do
    pid = start_registered_mob(hp: 500, sp: 50)

    MobSession.heal(pid, 100)
    _ = MobSession.get_state(pid)

    assert %{hp: 600, sp: 50} = registry_state()
  end

  test "coma republishes HP and SP, vanish HP and leaves SP" do
    pid = start_registered_mob(hp: 500, sp: 50)

    MobSession.apply_coma(pid, {:player, 42})
    _ = MobSession.get_state(pid)
    assert %{hp: 1, sp: 1} = registry_state()

    pid2 = start_registered_mob(hp: 500, sp: 50, instance_id: 2)
    MobSession.apply_vanish(pid2, 10, {:player, 42})
    _ = MobSession.get_state(pid2)
    assert %{hp: 400, sp: 50} = registry_state(2)
  end

  defp registry_state(instance_id \\ 1) do
    {:ok, {MobState, state, _pid}} = UnitRegistry.get_unit(:mob, instance_id)
    state
  end

  defp start_registered_mob(opts) do
    state = build_mob_state(opts)
    {:ok, pid} = MobSession.start_link(%{state: state, awake: false})
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, pid)
    pid
  end

  defp build_mob_state(opts) do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1_000,
      sp: 90,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1_200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    state =
      MobState.new(Keyword.get(opts, :instance_id, 1), mob_data, spawn, "prontera", 100, 100)

    %{
      state
      | hp: Keyword.fetch!(opts, :hp),
        sp: Keyword.fetch!(opts, :sp),
        calculated: %{state.calculated | max_hp: 1_000, max_sp: 90}
    }
  end
end
