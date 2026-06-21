defmodule Aesir.ZoneServer.Unit.Mob.MobSessionHpTest do
  @moduledoc """
  Verifies the mob HP-bar broadcast emits the protobuf `UnitHp` message after
  the QUIC + protobuf migration (replacing the legacy `ZC_HP_INFO`).
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Net.UnitHp
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState

  setup :verify_on_exit!

  test "a heal broadcasts a UnitHp with the mob's current and max HP" do
    test_pid = self()

    expect(Broadcast, :to_in_range, fn _map, _x, _y, _range, %UnitHp{} = packet ->
      send(test_pid, {:hp_broadcast, packet})
      :ok
    end)

    state = build_mob_state(hp: 500, max_hp: 1000)

    {:noreply, _state} = MobSession.handle_cast({:heal, 200}, state)

    assert_received {:hp_broadcast, %UnitHp{id: 1, hp: 700, max_hp: 1000}}
  end

  defp build_mob_state(opts) do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: opts[:max_hp],
      sp: 0,
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
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    state = MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
    %{state | hp: opts[:hp], max_hp: opts[:max_hp]}
  end
end
