defmodule Aesir.ZoneServer.Unit.Mob.MobSessionStatusTest do
  @moduledoc """
  Covers the asynchronous `{:casting, {:status_changed, status_id, event}}`
  session hook fired on application, tick, and expiry. Non-restricting statuses
  leave mob state intact; restricting statuses interrupt pending skills.
  """

  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Deluge
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  defp build_mob_state do
    mob_data =
      struct!(MobDefinition, %{
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
      })

    spawn_ref =
      struct!(MobSpawn, %{
        mob: 1001,
        amount: 1,
        respawn_time: 5000,
        spawn_area: struct!(SpawnArea, %{x: 100, y: 100})
      })

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

  describe "{:casting, {:status_changed, ...}} max-HP recalc (SC_DELUGE)" do
    setup do
      Registry.register_module(Deluge)
      :ok
    end

    test "an SC_DELUGE apply raises the HP ceiling without healing" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())
      StatusStorage.apply_status(:mob, state.instance_id, :sc_deluge, val1: 5)

      assert {:noreply, updated} =
               MobSession.handle_cast(
                 {:casting, {:status_changed, :sc_deluge, :apply}},
                 state
               )

      # level 5 -> +15% of the 1000 base ceiling; current HP is untouched.
      assert updated.max_hp == 1150
      assert updated.hp == state.hp
    end

    test "an SC_DELUGE removal caps overflow HP back down to the base ceiling" do
      buffed = %MobState{build_mob_state() | max_hp: 1150, hp: 1150}
      UnitRegistry.register_unit(:mob, buffed.instance_id, MobState, buffed, self())

      assert {:noreply, updated} =
               MobSession.handle_cast(
                 {:casting, {:status_changed, :sc_deluge, :removed}},
                 buffed
               )

      assert updated.max_hp == 1000
      assert updated.hp == 1000
    end

    test "a non-:max_hp_rate status change never touches the HP ceiling" do
      buffed = %MobState{build_mob_state() | max_hp: 1150, hp: 1150}
      UnitRegistry.register_unit(:mob, buffed.instance_id, MobState, buffed, self())

      assert {:noreply, ^buffed} =
               MobSession.handle_cast(
                 {:casting, {:status_changed, :sc_increase_agi, :apply}},
                 buffed
               )
    end
  end
end
