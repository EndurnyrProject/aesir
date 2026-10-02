defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaShieldchainTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaShieldchain
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup :verify_on_exit!

  @caster_id 46_001
  @target_id 46_002
  @guard 2101
  @left_hand 32

  defp definition do
    {:ok, definition} = Catalog.by_name(:pa_shieldchain)
    definition
  end

  @tag game_mode: :renewal
  test "renewal definition: 7/7/9/9/11 range, 0.8 s cast + 0.2 s fixed" do
    definition = definition()
    assert definition.id == 480
    assert definition.damage_base == :shield
    assert definition.range == [7, 7, 9, 9, 11]
    assert definition.cast_time == List.duplicate(800, 5)
    assert definition.fixed_cast_time == List.duplicate(200, 5)
    assert definition.after_cast_delay == List.duplicate(1_000, 5)
    assert definition.sp_cost == [28, 31, 34, 37, 40]
  end

  @tag game_mode: :pre_renewal
  test "classic definition: range 4, 1 s cast, no fixed cast" do
    definition = definition()
    assert definition.range == List.duplicate(4, 5)
    assert definition.cast_time == List.duplicate(1_000, 5)
    assert definition.fixed_cast_time == List.duplicate(0, 5)
  end

  @tag game_mode: :renewal
  test "renewal ratio folds shield weight, refine and base level into the ratio" do
    stub_guard(300)
    # (300 + 200 * 3 + 300 / 10 + 4 * 7) * 99 / 100 = 958 * 99 / 100
    assert PaShieldchain.skill_ratio(shield_caster(refine: 7, base_level: 99), 3) == 948
    # a level 120 mob has no shield: (300 + 200 * 3) * 120 / 100
    assert PaShieldchain.skill_ratio(mob_caster(), 3) == 1_080
  end

  @tag game_mode: :pre_renewal
  test "classic ratio is 100 plus 30 per level regardless of the shield" do
    stub_guard(300)
    assert PaShieldchain.skill_ratio(shield_caster(refine: 7, base_level: 99), 1) == 130
    assert PaShieldchain.skill_ratio(shield_caster(refine: 7, base_level: 99), 5) == 250
    assert PaShieldchain.skill_ratio(mob_caster(), 5) == 250
  end

  test "cast throws five displayed shield hits with +20 flat HIT" do
    stub_guard(300)
    caster = shield_caster(refine: 0, base_level: 50)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == 480
      assert opts[:skill_level] == 2
      assert opts[:damage_base] == :shield
      assert opts[:display_hit_count] == 5
      assert opts[:hit_rate_bonus_flat] == 20
      assert opts[:skip_crit] == true
      assert opts[:skip_range] == true
      refute Keyword.has_key?(opts, :ranged)
      :ok
    end)

    assert {:ok, ^caster} = PaShieldchain.cast(caster, {:unit, @target_id}, 2, definition())
  end

  test "validate refuses a shieldless player and lets a mob through" do
    stub_guard(300)

    assert :ok =
             PaShieldchain.validate(
               shield_caster(refine: 0, base_level: 50),
               {:unit, 1},
               1,
               definition()
             )

    assert {:error, :requires_shield} =
             PaShieldchain.validate(player(0, 50, []), {:unit, 1}, 1, definition())

    assert :ok = PaShieldchain.validate(mob_caster(), {:unit, 1}, 1, definition())
  end

  defp stub_guard(weight) do
    stub(ItemManagement, :get_item_by_id, fn @guard ->
      {:ok,
       %ItemDefinition{
         id: @guard,
         aegis_name: "Guard",
         name: "Guard",
         type: :armor,
         subtype: nil,
         weight: weight
       }}
    end)
  end

  defp shield_caster(refine: refine, base_level: base_level) do
    player(refine, base_level, [
      %InventoryItem{nameid: @guard, amount: 1, equip: @left_hand, identify: 1, refine: refine}
    ])
  end

  defp player(_refine, base_level, inventory) do
    base =
      PlayerState.new(%Character{
        id: @caster_id,
        account_id: @caster_id,
        name: "Paladin",
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
        base_level: base_level,
        job_level: 50,
        class: 4015
      })

    stats = %{base.stats | equipment: Stats.equipment_from_inventory(inventory)}

    %{
      base
      | stats: stats,
        inventory: Map.new(Enum.with_index(inventory, fn item, i -> {i, item} end))
    }
  end

  defp mob_caster do
    mob_data =
      struct(MobDefinition, %{
        id: 1_002,
        aegis_name: "TEST_MOB",
        name: "Test Mob",
        level: 120,
        hp: 1_000,
        stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
        atk: 50,
        matk: 60,
        def: 25,
        mdef: 10,
        attack_range: 2
      })

    spawn = %MobSpawn{
      mob: 1_002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 150, y: 150}
    }

    MobState.new(@target_id, mob_data, spawn, "prontera", 150, 150)
  end
end
