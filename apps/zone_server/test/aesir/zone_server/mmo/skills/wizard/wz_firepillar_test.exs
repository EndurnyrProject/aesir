defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzFirepillarTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzFirepillar
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Mimic.copy(SplashTargets)
    :ok
  end

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
      state: state || %{phase: :waiting, hit_budget: level + 2}
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

  @tag game_mode: :renewal

  test "definition and waiting placement match Renewal levels 1 and 10" do
    definition = WzFirepillar.definition()

    assert definition.max_level == 10
    assert definition.target_type == :ground
    assert definition.damage_kind == :magic
    assert definition.element == :fire
    assert definition.range == 9
    assert definition.hit_count == Enum.to_list(3..12)

    assert WzFirepillar.definition(:pre_renewal).cast_time == [
             3000,
             2700,
             2400,
             2100,
             1800,
             1500,
             1200,
             900,
             600,
             300
           ]

    assert WzFirepillar.definition(:pre_renewal).fixed_cast_time == []
    assert definition.splash_radius == 2
    assert definition.hit_interval == 2_000
    assert definition.sp_cost == List.duplicate(75, 10)
    assert definition.cast_time == [1920, 1728, 1536, 1344, 1152, 960, 768, 576, 384, 192]
    assert definition.fixed_cast_time == [480, 432, 384, 336, 288, 240, 192, 144, 96, 48]
    assert definition.after_cast_delay == List.duplicate(1000, 10)
    assert definition.unit_duration == List.duplicate(30_000, 10)

    assert {:ok, level_one} = WzFirepillar.on_place(group(1))
    assert level_one.cells == [@center]
    assert level_one.unit_range == 1
    assert level_one.state == %{phase: :waiting, hit_budget: 3}
    assert level_one.interval == 2_000
    assert level_one.duration == 30_000

    assert {:ok, level_ten} = WzFirepillar.on_place(group(10))
    assert level_ten.state == %{phase: :waiting, hit_budget: 12}
  end

  test "needs one Blue Gemstone from level six" do
    definition = WzFirepillar.definition()

    assert WzFirepillar.dynamic_item_cost(caster(%{}), {:ground, 150, 150}, 5, definition) == []

    assert WzFirepillar.dynamic_item_cost(caster(%{}), {:ground, 150, 150}, 6, definition) ==
             [%{id: @blue_gemstone, amount: 1}]
  end

  test "the placement itself leaves the gemstone to the cast's requirement" do
    caster = caster(%{0 => gemstone(2)})
    stub(Unit, :place, fn ^caster, :wz_firepillar, 6, @center -> {:ok, :group} end)

    assert {:ok, ^caster} =
             WzFirepillar.cast(caster, {:ground, 150, 150}, 6, WzFirepillar.definition())
  end

  test "a non-enemy in reach does not wake the waiting pillar" do
    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

    stub(SplashTargets, :eligible, fn refs, %{unit_id: @caster_id} ->
      Enum.filter(refs, &match?({:mob, _id}, &1))
    end)

    assert [{:mob, 2_001}] =
             WzFirepillar.unit_targets(group(1), @center, [{:player, 2_000}, {:mob, 2_001}])
  end

  test "an enemy in reach turns the waiting pillar into an active one without damage" do
    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
    reject(&Combat.apply_skill_unit_damage/7)

    assert {:ok, %Group{expires_at: 6_000} = active} =
             WzFirepillar.on_unit_hit(group(1), @center, {:mob, 2_001}, 5_000)

    assert %{phase: :active, activated_at: 5_000, unit_generation: 1, hit_budget: 3} =
             active.state
  end

  test "a waiting pillar on Land Protector ends without becoming active" do
    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
    reject(&Combat.apply_skill_unit_damage/7)

    :ok =
      Storage.insert(%Group{
        group_id: 9,
        skill_name: :sa_landprotector,
        map_name: @map_name,
        center: @center,
        cells: [@center],
        state: %{land_protector: true}
      })

    waiting = group(1)
    assert {:expire, ^waiting} = WzFirepillar.on_unit_hit(waiting, @center, {:mob, 2_001}, 5_000)
  end

  test "an active pillar does nothing in the pass that activated it" do
    reject(&Combat.splash_targets/4)
    reject(&Combat.apply_skill_unit_damage/7)

    active = group(1, %{phase: :active, activated_at: 5_000, hit_budget: 3})
    assert {:ok, ^active} = WzFirepillar.on_unit_hit(active, @center, {:mob, 2_001}, 5_000)
  end

  test "an active pillar bursts on every enemy in its splash area once, then is used" do
    test_pid = self()
    level = 6

    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

    stub(Combat, :splash_targets, fn @map_name, @center, 2, %{unit_id: @caster_id} ->
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
                                              hit_divisions: 8,
                                              divide_hits_for_player?: true ->
      assert caster.unit_id == @caster_id
      send(test_pid, {:hit, unit_type, target_id})
      :ok
    end)

    active =
      group(level, %{phase: :active, activated_at: 5_000, hit_budget: 8})

    assert {:ok, %Group{state: %{phase: :used}}} =
             WzFirepillar.on_unit_hit(active, @center, {:mob, 2_001}, 5_100)

    hits = received_hits()
    assert Enum.count(hits, &(&1 == {:mob, 2_001})) == 1
    assert Enum.count(hits, &(&1 == {:player, 2_002})) == 1
  end

  test "a used pillar strikes nobody" do
    reject(&Combat.resolve_combatant/1)
    reject(&Combat.splash_targets/4)
    reject(&Combat.apply_skill_unit_damage/7)

    used = group(1, %{phase: :used, activated_at: 5_000, hit_budget: 3})

    assert [] = WzFirepillar.unit_targets(used, @center, [{:mob, 2_001}])
    assert {:ok, ^used} = WzFirepillar.on_unit_hit(used, @center, {:mob, 2_001}, 6_000)
  end

  test "the unit pass wakes a pillar beside an enemy and bursts it on the next pass" do
    test_pid = self()
    stub(Catalog, :ground_module_for, fn :wz_firepillar -> {:ok, WzFirepillar} end)
    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
    stub(SplashTargets, :eligible, fn refs, _caster -> refs end)
    stub(Combat, :splash_targets, fn @map_name, @center, 1, _caster -> [{:mob, 2_001}] end)

    stub(Combat, :apply_skill_unit_damage, fn _caster, :mob, 2_001, 80, 1, :fire, 60, _opts ->
      send(test_pid, :hit)
      :ok
    end)

    manager = start_manager(2_000)
    allow(Combat, self(), manager)
    allow(SplashTargets, self(), manager)

    :ok = Manager.register(manager, group(1, nil, unit_range: 1, visibility: :public))
    :ok = SpatialIndex.add_unit(:mob, 2_001, 151, 150, @map_name)

    assert :ok = Manager.tick(manager, 2_000)
    refute_received :hit

    assert %Group{expires_at: 3_000, state: %{phase: :active, unit_generation: 1}} =
             Storage.get(1)

    assert :ok = Manager.tick(manager, 2_100)
    assert_received :hit
    refute_received :hit
    assert %Group{state: %{phase: :used}} = Storage.get(1)
  end

  test "the manager expires an untriggered pillar at its natural lifetime boundary" do
    now = 30_000
    stub(Catalog, :ground_module_for, fn :wz_firepillar -> {:ok, WzFirepillar} end)
    manager = start_manager(now)

    :ok =
      Manager.register(
        manager,
        group(1, %{phase: :waiting, hit_budget: 3}, expires_at: now)
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
