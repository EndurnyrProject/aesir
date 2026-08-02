defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AlchemistSummonSkillsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmCannibalize
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmSpheremine
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 1_000
  @plant_bottle 7_137
  @sphere_bottle 7_138

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", MapData.new("prontera", 30, 30)})
    Catalog.reload()
    :ok
  end

  setup :verify_on_exit!

  test "Cannibalize maps each level to its plant, lifetime, and HP override" do
    caster = caster(%{232 => 5}, @plant_bottle)
    test_pid = self()

    stub(UnitRegistry, :count_living_owned_mobs, fn @caster_id, _mob_id -> 0 end)

    expect(Coordinator, :summon_mob, 5, fn map, mob_id, x, y, opts ->
      send(test_pid, {:summon, map, mob_id, x, y, opts})
      {:ok, System.unique_integer([:positive])}
    end)

    Enum.each(
      [
        {1, 1_589, 300_000},
        {2, 1_579, 240_000},
        {3, 1_575, 180_000},
        {4, 1_555, 120_000},
        {5, 1_590, 60_000}
      ],
      fn {level, mob_id, lifetime_ms} ->
        assert {:ok, ^caster} =
                 AmCannibalize.cast(caster, {:ground, 11, 10}, level, AmCannibalize.definition())

        assert_received {:summon, "prontera", ^mob_id, 11, 10, opts}
        expected_hp = 2_000 + 200 * level
        assert opts[:owner_player_id] == @caster_id
        assert opts[:hp_override] == expected_hp
        assert opts[:lifetime_ms] == lifetime_ms
        assert opts[:no_exp] == true
        assert opts[:no_drops] == true

        configured = MobState.configure_summon(struct(MobState, %{hp: 1, max_hp: 1}), opts)
        assert configured.hp == expected_hp
        assert configured.max_hp == expected_hp
      end
    )
  end

  test "Sphere Mine summons a Marine Sphere for 30 seconds with EXP disabled and drops allowed" do
    caster = caster(%{233 => 5}, @sphere_bottle)

    stub(UnitRegistry, :count_living_owned_mobs, fn @caster_id, 1_142 -> 0 end)

    expect(Coordinator, :summon_mob, fn "prontera", 1_142, 11, 10, opts ->
      assert opts[:owner_player_id] == @caster_id
      assert opts[:lifetime_ms] == 30_000
      assert opts[:no_exp] == true
      assert opts[:no_drops] == false
      refute Keyword.has_key?(opts, :hp_override)
      {:ok, 9_001}
    end)

    assert {:ok, ^caster} =
             AmSpheremine.cast(caster, {:ground, 11, 10}, 5, AmSpheremine.definition())
  end

  test "a capped Cannibalize cast keeps its Plant Bottle and SP" do
    reject(&Coordinator.summon_mob/5)
    stub(UnitRegistry, :count_living_owned_mobs, fn @caster_id, 1_589 -> 5 end)
    caster = caster(%{232 => 1}, @plant_bottle)

    assert {:error, :summon_cap_reached} = Interpreter.cast(caster, 232, 1, {:ground, 11, 10})
    assert caster.stats.current_state.sp == 100
    assert caster.inventory[0].amount == 1
  end

  test "a capped Sphere Mine cast keeps its bottle and SP" do
    reject(&Coordinator.summon_mob/5)
    stub(UnitRegistry, :count_living_owned_mobs, fn @caster_id, 1_142 -> 3 end)
    caster = caster(%{233 => 1}, @sphere_bottle)

    assert {:error, :summon_cap_reached} = Interpreter.cast(caster, 233, 1, {:ground, 11, 10})
    assert caster.stats.current_state.sp == 100
    assert caster.inventory[0].amount == 1
  end

  test "successful casts consume the bottle and the correct SP" do
    stub(UnitRegistry, :count_living_owned_mobs, fn @caster_id, _mob_id -> 0 end)
    stub(Coordinator, :summon_mob, fn _map, _mob_id, _x, _y, _opts -> {:ok, 9_001} end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    assert {:ok, plant} =
             Interpreter.cast(caster(%{232 => 1}, @plant_bottle), 232, 1, {:ground, 11, 10})

    assert plant.stats.current_state.sp == 80
    assert plant.inventory == %{}

    assert {:ok, sphere} =
             Interpreter.cast(caster(%{233 => 1}, @sphere_bottle), 233, 1, {:ground, 11, 10})

    assert sphere.stats.current_state.sp == 90
    assert sphere.inventory == %{}
  end

  test "definitions expose ground targeting, costs, and cast timing" do
    for {definition, id, name, sp, bottle} <- [
          {AmCannibalize.definition(), 232, :am_cannibalize, 20, @plant_bottle},
          {AmSpheremine.definition(), 233, :am_spheremine, 10, @sphere_bottle}
        ] do
      assert definition.id == id
      assert definition.name == name
      assert definition.max_level == 5
      assert definition.target_type == :ground
      assert definition.sp_cost == List.duplicate(sp, 5)
      assert definition.item_cost == [%{id: bottle, amount: 1}]
      assert definition.cast_time == List.duplicate(1_600, 5)
      assert definition.fixed_cast_time == List.duplicate(400, 5)
      assert definition.after_cast_delay == List.duplicate(500, 5)
    end
  end

  defp caster(learned_skills, bottle_id) do
    %{
      character_id: @caster_id,
      x: 10,
      y: 10,
      map_name: "prontera",
      zeny: 0,
      skill_cooldowns: %{},
      act_delay_until: 0,
      inventory: %{0 => %InventoryItem{nameid: bottle_id, amount: 1, equip: 0}},
      pending_inventory_persist: [],
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{sp: 100, hp: 100},
        derived_stats: %{max_sp: 100, max_hp: 100},
        progression: %{base_level: 50, learned_skills: learned_skills},
        equipment: %{}
      }
    }
  end
end
