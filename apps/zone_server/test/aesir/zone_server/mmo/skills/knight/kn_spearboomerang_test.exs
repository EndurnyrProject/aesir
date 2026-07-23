defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnSpearboomerangTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnSpearboomerang
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup :verify_on_exit!

  @caster_id 1_000
  @target_id 2_000
  @map "prontera"
  @spear_id 1_400

  defp definition do
    {:ok, definition} = Catalog.by_name(:kn_spearboomerang)
    definition
  end

  test "Catalog.by_id(59) resolves to :kn_spearboomerang with its declared Renewal shape" do
    assert {:ok, definition} = Catalog.by_id(59)
    assert definition.name == :kn_spearboomerang
    assert definition.display_name == "Spear Boomerang"
    assert definition.max_level == 5
    assert definition.target_type == :target_enemy
    assert definition.damage_type == :damage
    assert definition.range == [3, 5, 7, 9, 11]
    assert definition.sp_cost == List.duplicate(10, 5)
  end

  test "Catalog.active_module_for/1 resolves kn_spearboomerang" do
    assert {:ok, KnSpearboomerang} = Catalog.active_module_for(:kn_spearboomerang)
  end

  describe "cast/4" do
    defp caster, do: %{character_id: @caster_id}

    test "skill_ratio scales as (100 + 50 * level)% at every level" do
      caster = caster()

      for level <- 1..5 do
        expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
          assert opts[:skill_id] == 59
          assert opts[:skill_level] == level
          assert opts[:skill_ratio] == 100 + 50 * level
          assert opts[:skip_crit] == true
          assert opts[:skip_range] == true
          :ok
        end)

        assert {:ok, ^caster} =
                 KnSpearboomerang.cast(caster, {:unit, @target_id}, level, definition())
      end
    end

    test "cast/4 propagates an attack error" do
      caster = caster()

      stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
        {:error, :dead_target}
      end)

      assert {:error, :dead_target} =
               KnSpearboomerang.cast(caster, {:unit, @target_id}, 3, definition())
    end
  end

  describe "validate/4 (weapon gate only - range is enforced by the interpreter's built-in per-level range check, not this callback)" do
    test "a spear-wielding player passes regardless of target distance or level" do
      caster = spear_caster(x: 0, y: 0)
      reject(&Combat.resolve_target_position/1)

      assert :ok = KnSpearboomerang.validate(caster, {:unit, @target_id}, 1, definition())
    end

    test "a bare-handed player is rejected" do
      caster = unarmed_caster(x: 0, y: 0)
      reject(&Combat.resolve_target_position/1)

      assert {:error, :requires_spear} =
               KnSpearboomerang.validate(caster, {:unit, @target_id}, 1, definition())
    end

    test "a mob caster bypasses the weapon gate entirely" do
      caster = mob_caster(x: 0, y: 0)
      reject(&Combat.resolve_target_position/1)

      assert :ok = KnSpearboomerang.validate(caster, {:unit, @target_id}, 1, definition())
    end
  end

  defp spear_caster(x: x, y: y) do
    player(
      x: x,
      y: y,
      inventory: [%InventoryItem{nameid: @spear_id, amount: 1, equip: 2, identify: 1}]
    )
  end

  defp unarmed_caster(x: x, y: y) do
    player(x: x, y: y, inventory: [])
  end

  defp player(x: x, y: y, inventory: inventory) do
    base =
      PlayerState.new(%Character{
        id: @caster_id,
        account_id: @caster_id,
        name: "Knight",
        last_map: @map,
        last_x: x,
        last_y: y,
        sex: "M",
        str: 40,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 70,
        job_level: 40,
        class: 7
      })

    stats = %{base.stats | equipment: Stats.equipment_from_inventory(inventory)}
    %{base | stats: stats}
  end

  defp mob_caster(x: x, y: y) do
    mob_data =
      struct(MobDefinition, %{
        id: 1_002,
        aegis_name: "TEST_MOB",
        name: "Test Mob",
        level: 25,
        hp: 1_000,
        stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
        atk: 50,
        matk: 60,
        def: 25,
        mdef: 10,
        attack_range: 2,
        skill_range: 11,
        chase_range: 12,
        walk_speed: 200,
        attack_delay: 1_200,
        attack_motion: 500,
        client_attack_motion: 400,
        damage_motion: 300,
        element: {:neutral, 1},
        race: :formless,
        size: :medium
      })

    spawn_ref = %MobSpawn{
      mob: 1_002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: x, y: y}
    }

    MobState.new(@caster_id, mob_data, spawn_ref, @map, x, y)
  end
end
