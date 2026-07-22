defmodule Aesir.ZoneServer.Unit.Mob.MobSessionRudeAttackTest do
  @moduledoc """
  Verifies rude-attack detection: a hit from an attacker beyond the mob's
  chase_range records the rude-attack signal on MobState, while a reachable
  attacker (or one whose position can't be resolved) does not.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :verify_on_exit!

  setup do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    :ok
  end

  test "a hit from within chase_range records no rude attack" do
    stub(SpatialIndex, :get_unit_position, fn :player, 42 -> {:ok, {105, 100, "prontera"}} end)

    state = build_mob_state()

    {:noreply, updated} = MobSession.handle_cast({:combat, {:apply_damage, 100, 42}}, state)

    assert updated.rude_attack_count == 0
    assert updated.rude_attacked? == false
  end

  test "a hit from beyond chase_range records a rude attack" do
    stub(SpatialIndex, :get_unit_position, fn :player, 42 -> {:ok, {100, 200, "prontera"}} end)

    state = build_mob_state()

    {:noreply, updated} = MobSession.handle_cast({:combat, {:apply_damage, 100, 42}}, state)

    assert updated.rude_attack_count == 1
    assert updated.rude_attacked? == true
  end

  test "an unresolvable attacker position records no rude attack and does not crash" do
    stub(SpatialIndex, :get_unit_position, fn
      :player, 42 -> {:error, :not_found}
      :mob, 42 -> {:error, :not_found}
    end)

    state = build_mob_state()

    {:noreply, updated} = MobSession.handle_cast({:combat, {:apply_damage, 100, 42}}, state)

    assert updated.rude_attack_count == 0
    assert updated.rude_attacked? == false
  end

  defp build_mob_state do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
  end
end
