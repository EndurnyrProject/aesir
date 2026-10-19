defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AnkleTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 37_400
  @mob_id 37_401
  @boss_id 37_402

  setup :setup_ets_tables

  test "immobilises a normal mob and a boss, sparing their attacks" do
    for {id, modes} <- [{@mob_id, []}, {@boss_id, [:detector, :status_immune, :knockback_immune]}] do
      register_mob(id, modes)

      assert :ok =
               Interpreter.apply_status(:mob, id, :sc_ankle,
                 duration: 2_000,
                 caster_id: @caster_id,
                 source_type: :player
               )

      refute Interpreter.can_move?(:mob, id)
      assert Interpreter.can_attack?(:mob, id)
    end
  end

  defp register_mob(id, modes) do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "PORING",
      name: "Poring",
      level: 1,
      hp: 50,
      sp: 0,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      atk: 7,
      matk: 0,
      def: 0,
      mdef: 0,
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      walk_speed: 400,
      attack_delay: 1_872,
      attack_motion: 672,
      client_attack_motion: 672,
      damage_motion: 480,
      element: {:water, 1},
      race: :plant,
      size: :medium,
      class: Aesir.ZoneServer.Mmo.MobManagement.MobMode.class(modes),
      modes: modes
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    state = MobState.new(id, mob_data, spawn_ref, "prontera", 101, 100)
    UnitRegistry.register_unit(:mob, id, MobState, state, self())
  end
end
