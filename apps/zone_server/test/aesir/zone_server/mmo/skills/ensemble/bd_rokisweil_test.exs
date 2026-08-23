defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRokisweilTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRokisweil
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.RokisWeil
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  Mimic.copy(Broadcast)

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    # The cast runs in the test process and applies through the real status
    # path, so the mob's non-zero vit/luk would otherwise let the debuff be
    # resisted on some seeds.
    stub(Resistance, :roll_success, fn _success_rate -> true end)

    Catalog.reload()
    :ok
  end

  test "definition matches the pinned Roki's Weil table" do
    assert {:ok, BdRokisweil} = Catalog.active_module_for(:bd_rokisweil)
    assert {:ok, definition} = Catalog.by_id(311)

    assert definition.max_level == 1
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.damage_kind == :misc
    assert definition.hit_count == 1
    assert definition.splash_radius == 4
    assert definition.sp_cost == [180]
    assert definition.duration == [30_000]
    assert definition.cast_time == [3_000]
    assert definition.fixed_cast_time == [1_000]
    assert definition.after_cast_delay == [300]
    assert definition.cooldown == [180_000]
    assert definition.require_weapon == [:musical, :whip]
    assert definition.unit_duration == []
    assert definition.item_cost == []
    assert BdRokisweil.__skill_capabilities__() == [:active, :ensemble]
    refute function_exported?(BdRokisweil, :dynamic_cost, 4)
  end

  test "snapshots to enemies without affecting the caster" do
    caster = caster()
    mob = mob()
    :ok = UnitRegistry.register_unit(:player, caster.character_id, PlayerState, caster, self())
    :ok = UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, self())
    :ok = SpatialIndex.add_unit(:player, caster.character_id, caster.x, caster.y, caster.map_name)
    :ok = SpatialIndex.add_unit(:mob, mob.instance_id, mob.x, mob.y, mob.map_name)

    assert {:ok, _caster} = BdRokisweil.cast(caster, :self, 1, BdRokisweil.definition())

    assert StatusStorage.has_status?(:mob, mob.instance_id, :sc_rokisweil)
    refute StatusStorage.has_status?(:player, caster.character_id, :sc_rokisweil)
  end

  test "an affected mob cannot begin a skill cast" do
    mob = mob()
    :ok = UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, self())

    assert :ok =
             StatusInterpreter.apply_status(:mob, mob.instance_id, :sc_rokisweil,
               caster_id: 1,
               bypass_resistance: true
             )

    assert {:rejected, ^mob} = CastingHandler.begin_cast(mob, mob_skill_row(), 0)
  end

  test "status prevents skills for thirty seconds and declares ensemble replacement" do
    metadata = RokisWeil.metadata()

    assert metadata.properties == [:debuff, :prevents_skills]
    assert metadata.duration == 30_000

    assert metadata.end_on_start == [
             :sc_richmankim,
             :sc_eternalchaos,
             :sc_drumbattle,
             :sc_nibelungen,
             :sc_rokisweil,
             :sc_intoabyss,
             :sc_siegfried
           ]
  end

  defp caster do
    %Character{
      id: 2,
      account_id: 2,
      name: "Bard",
      last_map: "test",
      last_x: 0,
      last_y: 0,
      class: 19,
      base_level: 100,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      party_id: 0
    }
    |> PlayerState.new()
  end

  defp mob do
    mob_data = %MobDefinition{
      id: 1,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 1,
      hp: 100,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 500
    }

    spawn_ref = %MobSpawn{
      mob: 1,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 0, y: 0}
    }

    MobState.new(1, mob_data, spawn_ref, "test", 0, 0)
  end

  defp mob_skill_row do
    %{skill_id: 19, cast_time: 50, delay: 5_000}
  end
end
