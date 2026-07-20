defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzFirepillarTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzFirepillar

  setup :setup_ets_tables
  setup :verify_on_exit!

  @caster_id 1_000
  @map_name "prontera"
  @center {150, 150}
  @blue_gemstone 717

  defp group(level, state \\ nil, attrs \\ []) do
    base = %Group{
      group_id: 1,
      skill_id: 80,
      skill_name: :wz_firepillar,
      level: level,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: @map_name,
      center: @center,
      cells: [@center],
      next_tick_at: 2_000,
      expires_at: 30_000,
      interval: 2_000,
      state: state || %{phase: :waiting, hit_budget: level + 2, target_delay: 400 + 200 * level}
    }

    struct(base, attrs)
  end

  defp caster(inventory) do
    %{inventory: inventory, pending_inventory_persist: []}
  end

  defp gemstone(amount), do: %InventoryItem{nameid: @blue_gemstone, amount: amount, equip: 0}

  defp start_manager(now) do
    manager =
      start_supervised!(
        {Manager,
         name: nil,
         clock: fn -> now end,
         schedule_tick: fn _pid, _interval -> :ok end,
         unit_available?: fn _unit_type, _unit_id, _map_name -> true end}
      )

    allow(Catalog, self(), manager)
    manager
  end

  test "definition and waiting placement match Renewal levels 1 and 10" do
    definition = WzFirepillar.definition()

    assert definition.id == 80
    assert definition.name == :wz_firepillar
    assert definition.max_level == 10
    assert definition.target_type == :ground
    assert definition.damage_kind == :magic
    assert definition.element == :fire
    assert definition.range == 9
    assert definition.hit_count == 3
    assert definition.splash_radius == 2
    assert definition.hit_interval == 2_000
    assert definition.sp_cost == List.duplicate(75, 10)
    assert definition.cast_time == [1920, 1728, 1536, 1344, 1152, 960, 768, 576, 384, 192]
    assert definition.fixed_cast_time == [480, 432, 384, 336, 288, 240, 192, 144, 96, 48]
    assert definition.after_cast_delay == List.duplicate(1000, 10)
    assert definition.unit_duration == List.duplicate(30_000, 10)

    assert {:ok, level_one} = WzFirepillar.on_place(group(1))
    assert level_one.cells == [@center]
    assert level_one.state == %{phase: :waiting, hit_budget: 3, target_delay: 600}
    assert level_one.interval == 2_000
    assert level_one.duration == 30_000

    assert {:ok, level_ten} = WzFirepillar.on_place(group(10))
    assert level_ten.state == %{phase: :waiting, hit_budget: 12, target_delay: 2400}
  end

  test "missing Blue Gemstone rejects a level-six cast before placement" do
    reject(&Unit.place/4)

    assert {:error, :missing_catalyst} =
             WzFirepillar.validate(caster(%{}), {:ground, 150, 150}, 6, WzFirepillar.definition())
  end

  test "a failed placement does not consume a level-six Blue Gemstone" do
    caster = caster(%{0 => gemstone(1)})
    stub(Unit, :place, fn ^caster, :wz_firepillar, 6, @center -> {:error, :invalid_target} end)

    assert {:error, :invalid_target} =
             WzFirepillar.cast(caster, {:ground, 150, 150}, 6, WzFirepillar.definition())
  end

  test "a successful level-six placement consumes exactly one Blue Gemstone" do
    caster = caster(%{0 => gemstone(2)})
    stub(Unit, :place, fn ^caster, :wz_firepillar, 6, @center -> {:ok, :group} end)

    assert {:ok, updated} =
             WzFirepillar.cast(caster, {:ground, 150, 150}, 6, WzFirepillar.definition())

    assert %{0 => %InventoryItem{amount: 1}} = updated.inventory
    assert [{original_inventory, updated_inventory, _change}] = updated.pending_inventory_persist
    assert original_inventory == caster.inventory
    assert updated_inventory == updated.inventory
  end

  test "an early non-enemy entry leaves the waiting pillar armed" do
    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
    stub(Combat, :splash_targets, fn @map_name, @center, 1, @caster_id -> [] end)
    reject(&Combat.apply_skill_unit_damage/7)

    assert {:ok, %Group{state: %{phase: :waiting, hit_budget: 3}}} =
             WzFirepillar.on_touch(group(1), {:player, 2_000})
  end

  test "a waiting pillar scans its Range-1 activation area for a stationary adjacent enemy" do
    test_pid = self()

    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

    stub(Combat, :splash_targets, fn @map_name, @center, 1, @caster_id ->
      [{:mob, 2_001}]
    end)

    stub(Combat, :apply_skill_unit_damage, fn _caster,
                                              :mob,
                                              2_001,
                                              80,
                                              1,
                                              :fire,
                                              60,
                                              bonus_matk: 150,
                                              hit_count: 3,
                                              dst_delay: 600,
                                              divide_hits_for_player?: true ->
      send(test_pid, :hit)
      :ok
    end)

    assert {:ok, %Group{state: %{phase: :active, hit_budget: 0}, expires_at: 3_000}} =
             WzFirepillar.on_interval(group(1), 2_000)

    assert_receive :hit
  end

  test "a trigger hits every target in the canonical activation area and starts the active lifetime" do
    test_pid = self()
    level = 6

    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

    stub(Combat, :splash_targets, fn @map_name, @center, radius, @caster_id
                                     when radius in [1, 2] ->
      [{:mob, 2_001}, {:player, 2_002}]
    end)

    stub(Combat, :apply_skill_unit_damage, fn caster,
                                              unit_type,
                                              target_id,
                                              80,
                                              ^level,
                                              :fire,
                                              160,
                                              bonus_matk: 400,
                                              hit_count: 8,
                                              dst_delay: 1600,
                                              divide_hits_for_player?: true ->
      assert caster.unit_id == @caster_id
      send(test_pid, {:hit, unit_type, target_id})
      :ok
    end)

    activated_at = System.monotonic_time(:millisecond)

    assert {:ok, %Group{state: %{phase: :active, hit_budget: 0}, next_tick_at: nil} = active} =
             WzFirepillar.on_touch(group(level), {:mob, 2_001})

    assert active.expires_at >= activated_at + 1_000
    hits = received_hits()
    assert Enum.count(hits, &(&1 == {:mob, 2_001})) == 1
    assert Enum.count(hits, &(&1 == {:player, 2_002})) == 1
  end

  test "an exhausted active pillar cannot deal a second burst" do
    reject(&Combat.resolve_combatant/1)
    reject(&Combat.splash_targets/4)
    reject(&Combat.apply_skill_unit_damage/7)

    assert {:ok, %Group{state: %{phase: :active, hit_budget: 0}}} =
             WzFirepillar.on_touch(group(1, %{phase: :active, hit_budget: 0}), {:mob, 2_001})
  end

  test "the manager expires an untriggered pillar at its natural lifetime boundary" do
    now = 30_000
    stub(Catalog, :ground_module_for, fn :wz_firepillar -> {:ok, WzFirepillar} end)
    manager = start_manager(now)

    :ok =
      Manager.register(
        manager,
        group(1, %{phase: :waiting, hit_budget: 3, target_delay: 600}, expires_at: now)
      )

    assert :ok = Manager.tick(manager, now)
    assert nil == Storage.get(1)
  end

  defp received_hits(acc \\ []) do
    receive do
      {:hit, unit_type, target_id} -> received_hits([{unit_type, target_id} | acc])
    after
      0 -> acc
    end
  end
end
