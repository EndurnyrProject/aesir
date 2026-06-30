defmodule Aesir.ZoneServer.Unit.Mob.MobSessionDropTest do
  @moduledoc """
  Verifies that a mob death widens the `:mob_killed` reward broadcast with the
  drop table, mob level, and death position, and that a death with no killer
  produces no broadcast at all.
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Phoenix.PubSub

  setup :verify_on_exit!
  setup :set_mimic_global

  test "killing a mob broadcasts a widened :mob_killed payload to the killer" do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Coordinator, :mob_died, fn _map, _id -> :ok end)

    :ok = PubSub.subscribe(Aesir.PubSub, "player:42")

    drops = [%MobDrop{item: "Red_Potion", rate: 10_000}]
    state = build_mob_state(hp: 1, max_hp: 1000, drops: drops)

    {:noreply, _state} = MobSession.handle_cast({:apply_damage, 100, 42}, state)

    assert_receive {:mob_killed, payload}
    assert payload.base_exp == 100
    assert payload.job_exp == 50
    assert payload.drops == drops
    assert payload.mob_level == 25
    assert payload.map == "prontera"
    assert payload.x == 100
    assert payload.y == 100
  end

  test "a mob death with no killer broadcasts nothing" do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Coordinator, :mob_died, fn _map, _id -> :ok end)

    :ok = PubSub.subscribe(Aesir.PubSub, "player:0")

    state =
      build_mob_state(hp: 1, max_hp: 1000, drops: [%MobDrop{item: "Red_Potion", rate: 10_000}])

    {:noreply, _state} = MobSession.handle_cast({:apply_damage, 100, nil}, state)

    refute_receive {:mob_killed, _payload}
  end

  defp build_mob_state(opts) do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      base_exp: 100,
      job_exp: 50,
      drops: opts[:drops],
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
