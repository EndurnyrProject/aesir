defmodule Aesir.ZoneServer.Unit.Mob.MobSessionStatusTest do
  @moduledoc """
  Covers the `{:casting, {:status_changed, status_id, event}}` session hook fired by the
  StatusTickManager. Today combat stats are live-folded on read and the display
  delta is broadcast by the interpreter, so the handler is a no-op that keeps
  the mob's state intact; it is the extension point Task 5 (cast interruption)
  consumes.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState

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
      skill_range: 10,
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

  describe "{:casting, {:status_changed, status_id, event}}" do
    test "a status tick leaves the mob state unchanged" do
      state = build_mob_state()

      assert {:noreply, ^state} =
               MobSession.handle_cast(
                 {:casting, {:status_changed, :sc_increase_agi, :tick}},
                 state
               )
    end

    test "a status expiry leaves the mob state unchanged" do
      state = build_mob_state()

      assert {:noreply, ^state} =
               MobSession.handle_cast(
                 {:casting, {:status_changed, :sc_increase_agi, :expired}},
                 state
               )
    end
  end
end
