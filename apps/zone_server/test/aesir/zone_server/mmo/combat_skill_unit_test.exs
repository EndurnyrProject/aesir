defmodule Aesir.ZoneServer.Mmo.CombatSkillUnitTest do
  @moduledoc """
  Tests `Combat.apply_skill_unit_damage/7`: the magic ground skill-unit hit path
  used by Storm Gust. Damage must come from `MagicDamageCalculator` (real
  MATK/MDEF/element), not a precomputed integer.
  """

  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 1000
  @target_id 2001
  @map_name "prontera"

  setup do
    Mimic.copy(ModifierCalculator)
    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
    :ok
  end

  defp caster(matk) do
    %Combatant{
      unit_id: @caster_id,
      unit_type: :player,
      gid: @caster_id,
      base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{
        atk: 1,
        def: 1,
        hit: 1,
        flee: 1,
        perfect_dodge: 1,
        matk: matk,
        mdef: 0,
        soft_mdef: 0
      },
      progression: %{base_level: 1, job_level: 1},
      element: {:neutral, 1},
      race: :demi_human,
      size: :medium,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 1
    }
  end

  defp build_mob_state(hard_mdef) do
    mob_definition = %MobDefinition{
      id: 1002,
      aegis_name: "TEST_MOB",
      name: "TestMob",
      level: 1,
      hp: 100,
      sp: 50,
      base_exp: 10,
      job_exp: 5,
      atk: 10,
      matk: 0,
      def: 5,
      mdef: hard_mdef,
      stats: %{str: 10, agi: 10, vit: 10, int: 0, dex: 10, luk: 5},
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      element: {:water, 1},
      race: :formless,
      size: :medium,
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      ai_type: 0,
      modes: [],
      drops: []
    }

    %MobState{
      instance_id: @target_id,
      mob_id: 1002,
      mob_data: mob_definition,
      spawn_ref: %MobSpawn{
        mob: 1002,
        amount: 1,
        respawn_time: 5_000,
        spawn_area: %MobSpawn.SpawnArea{x: 150, y: 150, xs: 0, ys: 0}
      },
      x: 150,
      y: 150,
      map_name: @map_name,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      spawned_at: System.system_time(:second),
      aggro_list: %{}
    }
  end

  test "computes magic damage from MATK/MDEF/element, broadcasts, and applies it" do
    test_pid = self()
    mob_state = build_mob_state(10)

    stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
      {:ok, {MobState, mob_state, test_pid}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id ->
      {:ok, {150, 150, @map_name}}
    end)

    stub(Broadcast, :to_in_range, fn @map_name, 150, 150, _range, packet ->
      send(test_pid, {:broadcast, packet.damage, packet.skill_id, packet.src_id})
      :ok
    end)

    stub(MobSession, :apply_damage, fn ^test_pid, damage, nil ->
      send(test_pid, {:damage, damage})
      :ok
    end)

    # MATK 100, water vs water (resist) modifier, hard 10 / soft 5.
    assert :ok =
             Combat.apply_skill_unit_damage(caster(100), :mob, @target_id, 89, 10, :water, 600)

    assert_received {:broadcast, damage, 89, @caster_id}
    assert_received {:damage, ^damage}
    assert damage > 0
  end

  test "skips cleanly when the target cannot be resolved" do
    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:error, :not_found} end)
    stub(UnitRegistry, :get_player_pid, fn @target_id -> {:error, :not_found} end)

    reject(&Broadcast.to_in_range/5)
    reject(&MobSession.apply_damage/3)

    assert {:error, :target_not_found} =
             Combat.apply_skill_unit_damage(caster(100), :mob, @target_id, 89, 10, :water, 600)
  end
end
