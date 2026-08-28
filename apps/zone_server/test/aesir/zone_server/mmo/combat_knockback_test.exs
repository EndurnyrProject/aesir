defmodule Aesir.ZoneServer.Mmo.CombatKnockbackTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(Cell)
    Mimic.copy(MapCache)
    :ok
  end

  @map_name "prontera"
  @mob_id 2001
  @from {150, 150}

  defp mob_state(x, y, modes \\ []) do
    %MobState{
      instance_id: @mob_id,
      mob_id: 1002,
      mob_data: %{modes: modes},
      spawn_ref: %{},
      x: x,
      y: y,
      map_name: @map_name,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      spawned_at: 0
    }
  end

  defp stub_movable_mob(opts \\ []) do
    {x, y} = Keyword.get(opts, :position, {151, 150})
    modes = Keyword.get(opts, :modes, [])
    traversable? = Keyword.get(opts, :traversable?, fn _from, _to -> true end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {x, y, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, :map} end)
    stub(Cell, :step_traversable?, fn @map_name, from, to -> traversable?.(from, to) end)

    stub(UnitRegistry, :get_unit, fn :mob, @mob_id ->
      {:ok, {MobState, mob_state(x, y, modes), self()}}
    end)
  end

  test "skill combines native and equipment distances into one displacement" do
    attacker =
      CombatTestHelper.create_player_combatant(position: @from)
      |> Map.put(:equip_modifiers, %{{:add_skill_blow, 18} => 2})

    target = CombatTestHelper.create_mob_combatant(unit_id: @mob_id, position: {151, 150})

    stub_movable_mob()

    result = %{hit?: true, target_survives?: true, coma?: false}

    assert {:ok, {156, 150}} =
             Knockback.skill(attacker, target, 18, result, base_distance: 3)

    assert_received {:"$gen_cast", {:movement, {:displace, 151, 150, @map_name, 156, 150}}}
    refute_received {:"$gen_cast", {:movement, _movement}}
  end

  test "skill native gates do not suppress equipment-only distance" do
    attacker =
      CombatTestHelper.create_player_combatant(position: @from)
      |> Map.put(:equip_modifiers, %{{:add_skill_blow, 18} => 2})

    target = CombatTestHelper.create_mob_combatant(unit_id: @mob_id, position: {151, 150})
    result = %{hit?: true, target_survives?: false, coma?: false}
    stub_movable_mob()

    gated_options = [
      [base_distance: 3, native_enabled: false],
      [base_distance: 3, native_target_types: [:player]],
      [base_distance: 3, native_requires_survival: true]
    ]

    for opts <- gated_options do
      assert {:ok, {153, 150}} = Knockback.skill(attacker, target, 18, result, opts)

      assert_received {:"$gen_cast", {:movement, {:displace, 151, 150, @map_name, 153, 150}}}
      refute_received {:"$gen_cast", {:movement, _movement}}
    end
  end

  test "skill coma counts as surviving for the native survival gate" do
    attacker = CombatTestHelper.create_player_combatant(position: @from)
    target = CombatTestHelper.create_mob_combatant(unit_id: @mob_id, position: {151, 150})
    result = %{hit?: true, target_survives?: false, coma?: true}
    stub_movable_mob()

    assert {:ok, {154, 150}} =
             Knockback.skill(attacker, target, 18, result,
               base_distance: 3,
               native_requires_survival: true
             )

    assert_received {:"$gen_cast", {:movement, {:displace, 151, 150, @map_name, 154, 150}}}
  end

  test "skill misses and zero final distance do not request knockback" do
    target = CombatTestHelper.create_mob_combatant(unit_id: @mob_id, position: {151, 150})

    attacker =
      CombatTestHelper.create_player_combatant(position: @from)
      |> Map.put(:equip_modifiers, %{{:add_skill_blow, 18} => -3})

    reject(&SpatialIndex.get_unit_position/2)

    assert :ok =
             Knockback.skill(
               attacker,
               target,
               18,
               %{hit?: false, target_survives?: true, coma?: false},
               base_distance: 5
             )

    assert :ok =
             Knockback.skill(
               attacker,
               target,
               18,
               %{hit?: true, target_survives?: true, coma?: false},
               base_distance: 3
             )
  end

  test "skill preserves a caller-supplied knockback origin" do
    attacker =
      CombatTestHelper.create_player_combatant(position: @from)
      |> Map.put(:equip_modifiers, %{{:add_skill_blow, 18} => 2})

    target = CombatTestHelper.create_mob_combatant(unit_id: @mob_id, position: {151, 150})
    result = %{hit?: true, target_survives?: true, coma?: false}
    stub_movable_mob()

    assert {:ok, {149, 150}} =
             Knockback.skill(attacker, target, 18, result, origin: {152, 150})

    assert_received {:"$gen_cast", {:movement, {:displace, 151, 150, @map_name, 149, 150}}}
  end

  test "skill keeps existing boss knockback immunity" do
    attacker =
      CombatTestHelper.create_player_combatant(position: @from)
      |> Map.put(:equip_modifiers, %{{:add_skill_blow, 18} => 2})

    target = CombatTestHelper.create_mob_combatant(unit_id: @mob_id, position: {151, 150})
    result = %{hit?: true, target_survives?: true, coma?: false}
    stub_movable_mob(modes: [:boss])

    assert {:ok, {151, 150}} = Knockback.skill(attacker, target, 18, result)
    refute_received {:"$gen_cast", {:movement, _movement}}
  end

  test "skill keeps existing blocked-cell collision behavior" do
    attacker =
      CombatTestHelper.create_player_combatant(position: @from)
      |> Map.put(:equip_modifiers, %{{:add_skill_blow, 18} => 2})

    target = CombatTestHelper.create_mob_combatant(unit_id: @mob_id, position: {151, 150})
    result = %{hit?: true, target_survives?: true, coma?: false}
    stub_movable_mob(traversable?: fn _from, _to -> false end)

    assert {:ok, {151, 150}} = Knockback.skill(attacker, target, 18, result)
    refute_received {:"$gen_cast", {:movement, _movement}}
  end

  test "knockback sends expected and landing cells to the owning session" do
    test_pid = self()

    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {151, 150, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, :map} end)

    # A wall at x == 154: cells 152 and 153 are walkable, 154 is not.
    stub(Cell, :step_traversable?, fn @map_name, _from, {x, _y} -> x < 154 end)

    stub(UnitRegistry, :get_unit, fn :mob, @mob_id ->
      {:ok, {MobState, mob_state(151, 150), test_pid}}
    end)

    reject(&Broadcast.to_in_range/5)

    {from_x, from_y} = @from
    assert {:ok, {153, 150}} = Combat.knockback(:mob, @mob_id, from_x, from_y, 5)

    assert_received {:"$gen_cast", {:movement, {:displace, 151, 150, @map_name, 153, 150}}}
  end

  test "hostile knockback and pull leave a boss mob unchanged" do
    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {151, 150, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, :map} end)

    stub(UnitRegistry, :get_unit, fn :mob, @mob_id ->
      {:ok, {MobState, mob_state(151, 150, [:boss]), self()}}
    end)

    reject(&Cell.step_traversable?/3)
    reject(&Broadcast.to_in_range/5)

    {from_x, from_y} = @from
    assert {:ok, {151, 150}} = Combat.knockback(:mob, @mob_id, from_x, from_y, 5)
    assert {:ok, {151, 150}} = Combat.pull_to(:mob, @mob_id, 155, 150)
    refute_received {:"$gen_cast", {:movement, _movement}}
  end

  test "a player with the no_knockback equipment flag is not blown away" do
    player_id = 3001

    player =
      PlayerStateFixture.build(%{
        character_id: player_id,
        stats: %{modifiers: %{equipment: %{no_knockback: 1}}}
      })

    stub(SpatialIndex, :get_unit_position, fn :player, ^player_id ->
      {:ok, {151, 150, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, :map} end)

    stub(UnitRegistry, :get_unit, fn :player, ^player_id ->
      {:ok, {PlayerState, player, self()}}
    end)

    reject(&Cell.step_traversable?/3)
    reject(&Broadcast.to_in_range/5)

    {from_x, from_y} = @from
    assert {:ok, {151, 150}} = Combat.knockback(:player, player_id, from_x, from_y, 5)
    refute_received {:"$gen_cast", {:movement, _movement}}
  end

  test "knockback with no walkable cell leaves the unit in place" do
    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {151, 150, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, :map} end)

    stub(Cell, :step_traversable?, fn @map_name, _from, _to -> false end)

    stub(UnitRegistry, :get_unit, fn :mob, @mob_id ->
      {:ok, {MobState, mob_state(151, 150), self()}}
    end)

    {from_x, from_y} = @from
    assert {:ok, {151, 150}} = Combat.knockback(:mob, @mob_id, from_x, from_y, 5)
  end

  test "knockback rejects a corpse before traversing a movable path" do
    corpse = %{mob_state(151, 150) | hp: 0, is_dead: true}

    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {151, 150, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, :map} end)

    expect(UnitRegistry, :get_unit, fn :mob, @mob_id ->
      {:ok, {MobState, corpse, self()}}
    end)

    reject(&Cell.step_traversable?/3)
    reject(&Broadcast.to_in_range/5)

    {from_x, from_y} = @from
    assert {:error, :target_dead} = Combat.knockback(:mob, @mob_id, from_x, from_y, 5)
  end

  test "knockback rejects a corpse when source and target share a cell" do
    corpse = %{mob_state(151, 150) | hp: 0, is_dead: true}

    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {151, 150, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, :map} end)

    expect(UnitRegistry, :get_unit, fn :mob, @mob_id ->
      {:ok, {MobState, corpse, self()}}
    end)

    reject(&Cell.step_traversable?/3)
    reject(&Broadcast.to_in_range/5)

    assert {:error, :target_dead} = Combat.knockback(:mob, @mob_id, 151, 150, 5)
  end

  test "knockback ignores skill-unit cells without casting to their manager" do
    test_pid = self()

    stub(SpatialIndex, :get_unit_position, fn :skill_unit, @mob_id ->
      {:ok, {151, 150, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, :map} end)
    stub(Cell, :traversable?, fn _map_name, _x, _y -> true end)

    stub(UnitRegistry, :get_unit, fn :skill_unit, @mob_id ->
      {:ok, {__MODULE__, %{}, test_pid}}
    end)

    reject(&Broadcast.to_in_range/5)

    {from_x, from_y} = @from
    assert :ok = Combat.knockback(:skill_unit, @mob_id, from_x, from_y, 5)
    refute_received {:"$gen_cast", {:movement, {:knocked_back, _, _}}}
  end

  test "pull-to finds a valid detour around an obstacle" do
    test_pid = self()

    map_data =
      MapData.new(@map_name, 10, 10)
      |> MapData.set_cell(4, 5, GatType.wall())
      |> MapData.set_cell(5, 5, GatType.wall())
      |> MapData.set_cell(6, 5, GatType.wall())

    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {1, 5, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, map_data} end)

    stub(UnitRegistry, :get_unit, fn :mob, @mob_id ->
      {:ok, {MobState, mob_state(1, 5), test_pid}}
    end)

    assert {:ok, {8, 5}} = Combat.pull_to(:mob, @mob_id, 8, 5)

    assert_received {:"$gen_cast", {:movement, {:displace, 1, 5, @map_name, 8, 5}}}
  end

  test "pull-to does not cut through a blocked diagonal corner" do
    map_data =
      MapData.new(@map_name, 2, 2)
      |> MapData.set_cell(1, 0, GatType.wall())
      |> MapData.set_cell(0, 1, GatType.wall())

    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {0, 0, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, map_data} end)

    stub(UnitRegistry, :get_unit, fn :mob, @mob_id ->
      {:ok, {MobState, mob_state(0, 0), self()}}
    end)

    assert {:ok, {0, 0}} = Combat.pull_to(:mob, @mob_id, 1, 1)
    refute_received {:"$gen_cast", {:movement, {:displace, _, _, _, _, _}}}
  end

  test "knockback returns an error when the owning session is unavailable" do
    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {151, 150, @map_name}}
    end)

    stub(MapCache, :get, fn @map_name -> {:ok, :map} end)
    stub(Cell, :step_traversable?, fn @map_name, _from, _to -> true end)
    stub(UnitRegistry, :get_unit, fn :mob, @mob_id -> {:error, :not_found} end)

    {from_x, from_y} = @from

    assert {:error, :owner_unavailable} =
             Combat.knockback(:mob, @mob_id, from_x, from_y, 5)
  end

  test "knockback returns an error when the unit map is unavailable" do
    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id ->
      {:ok, {151, 150, "missing"}}
    end)

    stub(MapCache, :get, fn "missing" -> {:error, :not_found} end)

    stub(UnitRegistry, :get_unit, fn :mob, @mob_id ->
      {:ok, {MobState, mob_state(151, 150), self()}}
    end)

    {from_x, from_y} = @from
    assert {:error, :not_found} = Combat.knockback(:mob, @mob_id, from_x, from_y, 5)
  end
end
