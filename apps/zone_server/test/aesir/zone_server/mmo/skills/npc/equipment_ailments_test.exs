defmodule Aesir.ZoneServer.Mmo.Skills.Npc.EquipmentAilmentsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcCriticalwound
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcWidebleeding
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcWidesilence
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    Mimic.copy(Resistance)
    stub(Resistance, :roll_rate, fn _ -> true end)
    caster = player(88_401, 100, 100)
    register(caster)
    %{caster: caster}
  end

  test "per-level splash geometry uses the declared level and caps over-level selections" do
    definition =
      Definition.build!(
        [
          id: 99_001,
          name: :test_radius,
          display_name: "Test",
          max_level: 5,
          splash_radius: [2, 5, 8, 11, 14]
        ],
        __MODULE__
      )

    assert Definition.splash_radius_at_level(definition, 0) == 2
    assert Definition.splash_radius_at_level(definition, 2) == 5
    assert Definition.splash_radius_at_level(definition, 9) == 14
    assert Definition.splash_radius_at_level(%{definition | splash_radius: 3}, 5) == 3
  end

  test "a wide ailment includes square corners and same-cell enemies but not allies or outside units",
       %{caster: caster} do
    near = mob(88_402, 102, 102)
    same_cell = mob(88_403, 100, 100)
    outside = mob(88_404, 103, 100)
    friend = player(88_405, 101, 100)
    for unit <- [near, same_cell, outside, friend], do: register(unit)

    assert {:ok, ^caster} =
             NpcWidesilence.cast(caster, :self, 1, NpcWidesilence.definition())

    assert StatusStorage.has_status?(:mob, near.instance_id, :sc_silence)
    assert StatusStorage.has_status?(:mob, same_cell.instance_id, :sc_silence)
    refute StatusStorage.has_status?(:mob, outside.instance_id, :sc_silence)
    refute StatusStorage.has_status?(:player, friend.character_id, :sc_silence)
    refute StatusStorage.has_status?(:player, caster.character_id, :sc_silence)
  end

  test "mob self-target adaptation applies bleeding with the mob as source", %{caster: player} do
    caster = mob(88_406, 101, 100)
    register(caster)

    assert {:ok, ^caster} =
             NpcWidebleeding.cast(
               caster,
               {:unit, caster.instance_id},
               2,
               NpcWidebleeding.definition()
             )

    assert %{source_type: :mob, source_id: 88_406, val1: 2} =
             StatusStorage.get_status(:player, player.character_id, :sc_bleeding)

    refute StatusStorage.has_status?(:mob, caster.instance_id, :sc_bleeding)
  end

  test "Critical Wounds uses an ordinary weapon hit and only a connecting hit applies its rider",
       %{caster: caster} do
    target = mob(88_407, 101, 100)
    register(target)

    stub(Combat, :execute_skill_attack, fn ^caster, target_id, opts ->
      assert target_id == target.instance_id
      assert opts[:skill_ratio] == 100
      assert opts[:skip_crit]
      assert opts[:skip_range]
      assert opts[:hit_rate_bonus_pct] in [nil, 0]
      refute Keyword.has_key?(opts, :element)
      {:ok, %{hit?: false}}
    end)

    assert {:ok, ^caster} =
             NpcCriticalwound.cast(
               caster,
               {:unit, target.instance_id},
               2,
               NpcCriticalwound.definition()
             )

    refute StatusStorage.has_status?(:mob, target.instance_id, :sc_criticalwound)

    stub(Combat, :execute_skill_attack, fn _, _, _ -> {:ok, %{hit?: true}} end)

    assert {:ok, ^caster} =
             NpcCriticalwound.cast(
               caster,
               {:unit, target.instance_id},
               2,
               NpcCriticalwound.definition()
             )

    assert %{val1: 2, val2: 40, source_type: :player, source_id: 88_401} =
             StatusStorage.get_status(:mob, target.instance_id, :sc_criticalwound)
  end

  defp player(id, x, y) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Ailment#{id}",
      class: 0,
      base_level: 1,
      vit: 0,
      int: 0,
      luk: 0,
      hp: 100,
      sp: 100,
      last_map: "prontera",
      last_x: x,
      last_y: y
    })
  end

  defp mob(id, x, y) do
    definition = %MobDefinition{
      id: 1002,
      aegis_name: "TEST",
      name: "Test",
      level: 1,
      hp: 1_000,
      sp: 0,
      atk: 1,
      matk: 0,
      def: 0,
      mdef: 0,
      stats: %{str: 1, agi: 1, vit: 0, int: 0, dex: 1, luk: 0},
      attack_range: 1,
      skill_range: 9,
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: x, y: y}
    }

    MobState.new(id, definition, spawn, "prontera", x, y)
  end

  defp register(%module{} = unit) do
    type = module.get_unit_type(unit)
    id = module.get_unit_id(unit)
    :ok = UnitRegistry.register_unit(type, id, module, unit, self())
    :ok = SpatialIndex.add_unit(type, id, unit.x, unit.y, unit.map_name)
  end
end
