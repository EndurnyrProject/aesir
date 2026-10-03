defmodule Aesir.ZoneServer.Mmo.Skills.Champion.ChPalmstrikeTest do
  use ExUnit.Case, async: false

  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.DamageDealt
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skills.Champion.ChPalmstrike
  alias Aesir.ZoneServer.Mmo.Skills.Champion.Formulas
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  @caster_id 38_200
  @target_id 38_201

  setup do
    register_mob(@target_id)
    :ok
  end

  test "requires Fury" do
    caster = caster()
    assert {:error, :requires_explosion_spirits} = validate(caster)

    :ok = StatusStorage.apply_status(:player, @caster_id, :sc_explosionspirits, duration: 60_000)
    assert :ok = validate(caster)
  end

  test "the cast shows a zero-damage hit and schedules the blow after an attack motion" do
    caster = caster()
    test_pid = self()

    stub(Broadcast, :to_in_range, fn "prontera", _x, _y, _range, packet ->
      send(test_pid, {:broadcast, packet})
      :ok
    end)

    reject(&Combat.execute_skill_attack/3)

    before = System.monotonic_time(:millisecond)
    assert {:ok, ^caster} = ChPalmstrike.cast(caster, {:unit, @target_id}, 3, definition())

    assert_received {:broadcast, %DamageDealt{damage: 0, target_id: @target_id}}

    delay =
      Formulas.palm_impact_delay(div(AttackSpeed.calculate_delay_from_stats(caster.stats), 2))

    payload = %{target: {:mob, @target_id}, map_name: "prontera", level: 3}
    assert_receive {:skill, {:deferred, ChPalmstrike, ^payload}}, delay + 200
    assert System.monotonic_time(:millisecond) - before >= delay
  end

  describe "deferred/2" do
    test "a landed blow strikes with its ratio and native push" do
      caster = caster()

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_id] == 370
        assert opts[:skill_ratio] == Formulas.palm_ratio(3, 40, 99)
        assert opts[:base_distance] == 3
        assert opts[:skip_range]
        assert opts[:report_hit]
        {:ok, %{hit?: true, damage: 100, target_survives?: true, coma?: false}}
      end)

      reject(&Knockback.knockback/5)

      assert :ok = ChPalmstrike.deferred(payload(), caster)
    end

    test "a miss still pushes the target three cells away from the caster" do
      caster = caster()

      stub(Combat, :execute_skill_attack, fn _caster, @target_id, _opts ->
        {:ok, %{hit?: false, damage: 0, target_survives?: true, coma?: false}}
      end)

      expect(Knockback, :knockback, fn :mob, @target_id, 50, 50, 3 -> :ok end)

      assert :ok = ChPalmstrike.deferred(payload(), caster)
    end

    test "a hidden target is only pushed" do
      :ok = StatusStorage.apply_status(:mob, @target_id, :sc_hiding, duration: 60_000)
      reject(&Combat.execute_skill_attack/3)
      expect(Knockback, :knockback, fn :mob, @target_id, 50, 50, 3 -> :ok end)

      assert :ok = ChPalmstrike.deferred(payload(), caster())
    end

    test "a stale blow does nothing" do
      reject(&Combat.execute_skill_attack/3)
      reject(&Knockback.knockback/5)

      moved = %{caster() | map_name: "geffen"}
      dead = put_in(caster().stats.current_state.hp, 0)
      gone = %{payload() | target: {:mob, 999}}

      assert :ok = ChPalmstrike.deferred(payload(), moved)
      assert :ok = ChPalmstrike.deferred(payload(), dead)
      assert :ok = ChPalmstrike.deferred(gone, caster())
    end
  end

  defp payload, do: %{target: {:mob, @target_id}, map_name: "prontera", level: 3}

  defp validate(caster),
    do: ChPalmstrike.validate(caster, {:unit, @target_id}, 3, definition())

  defp definition, do: ChPalmstrike.definition()

  defp caster do
    PlayerState.new(%Character{
      id: @caster_id,
      account_id: @caster_id,
      name: "Champion",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      str: 40,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 99,
      job_level: 50,
      class: 4016,
      hp: 100,
      max_hp: 100
    })
  end

  defp register_mob(id) do
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
      modes: []
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 51, y: 50}
    }

    state = MobState.new(id, mob_data, spawn_ref, "prontera", 51, 50)
    :ok = UnitRegistry.register_unit(:mob, id, MobState, state, self())
    :ok = SpatialIndex.add_unit(:mob, id, 51, 50, "prontera")
  end
end
