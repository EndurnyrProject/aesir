defmodule Aesir.ZoneServer.Unit.Mob.MobSessionKillGainTest do
  @moduledoc """
  A mob death broadcasts a `{:loot, {:kill_gain, ...}}` message to the killing
  blow's reward owner carrying the recorded attack-type classification, so the
  killer can be granted the on-kill HP/SP gain equipment bonuses. The gain is
  decoupled from drops: a no-drop mob still announces the gain.
  """
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Phoenix.PubSub

  setup :verify_on_exit!
  setup {Aesir.MimicMode, :global}
  setup :setup_ets_tables

  setup do
    Mimic.copy(Aesir.ZoneServer.Unit.Mob.KillExp)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Coordinator, :mob_died, fn _map, _id, _killer -> :ok end)

    stub(Aesir.ZoneServer.Unit.Mob.KillExp, :distribute_typed, fn _log, _b, _j, _l, _m, _r, _s ->
      :ok
    end)

    :ok = Lifecycle.subscribe()
    :ok
  end

  test "a recorded melee killing blow announces a melee kill_gain to the killer" do
    :ok = PubSub.subscribe(Aesir.PubSub, "player:42")
    state = build_mob_state(hp: 1, max_hp: 1000, drops: [])

    {:noreply, noted} =
      MobSession.handle_cast({:combat, {:note_hit_type, 42, :melee}}, state)

    {:noreply, _dead} = MobSession.handle_cast({:combat, {:apply_damage, 100, 42}}, noted)

    assert_receive {:loot,
                    {:kill_gain,
                     %{kill_bf: :melee, mob_race: :formless, final_source: {:player, 42}}}}
  end

  test "a magic killing blow announces a magic kill_gain" do
    :ok = PubSub.subscribe(Aesir.PubSub, "player:42")
    state = build_mob_state(hp: 1, max_hp: 1000, drops: [])

    {:noreply, noted} =
      MobSession.handle_cast({:combat, {:note_hit_type, 42, :magic}}, state)

    {:noreply, _dead} = MobSession.handle_cast({:combat, {:apply_damage, 100, 42}}, noted)

    assert_receive {:loot, {:kill_gain, %{kill_bf: :magic, final_source: {:player, 42}}}}
  end

  test "the kill_gain announcement fires even for a no-drop mob" do
    :ok = PubSub.subscribe(Aesir.PubSub, "player:42")

    state =
      build_mob_state(hp: 1, max_hp: 1000, drops: [])
      |> Map.put(:no_drops, true)

    {:noreply, noted} =
      MobSession.handle_cast({:combat, {:note_hit_type, 42, :ranged}}, state)

    {:noreply, _dead} = MobSession.handle_cast({:combat, {:apply_damage, 100, 42}}, noted)

    assert_receive {:loot, {:kill_gain, %{kill_bf: :ranged, final_source: {:player, 42}}}}
    refute_receive {:loot, {:mob_killed, _payload}}
  end

  test "an unrecorded killing blow announces no kill_gain" do
    :ok = PubSub.subscribe(Aesir.PubSub, "player:42")
    state = build_mob_state(hp: 1, max_hp: 1000, drops: [])

    {:noreply, _dead} = MobSession.handle_cast({:combat, {:apply_damage, 100, 42}}, state)

    refute_receive {:loot, {:kill_gain, _payload}}
  end

  test "each attacker reads its own recorded classification" do
    :ok = PubSub.subscribe(Aesir.PubSub, "player:42")
    :ok = PubSub.subscribe(Aesir.PubSub, "player:99")
    state = build_mob_state(hp: 1, max_hp: 1000, drops: [])

    {:noreply, s1} = MobSession.handle_cast({:combat, {:note_hit_type, 99, :magic}}, state)
    {:noreply, s2} = MobSession.handle_cast({:combat, {:note_hit_type, 42, :melee}}, s1)

    {:noreply, _dead} = MobSession.handle_cast({:combat, {:apply_damage, 100, 42}}, s2)

    assert_receive {:loot, {:kill_gain, %{kill_bf: :melee, final_source: {:player, 42}}}}
    refute_receive {:loot, {:kill_gain, %{final_source: {:player, 99}}}}
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
