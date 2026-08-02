defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcSelfdestructionTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcSelfdestruction
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    Mimic.copy(DamageApplication)
    :ok
  end

  setup :verify_on_exit!

  test "deals the caster's current HP to nearby enemy mobs, knocks them back, and kills the caster" do
    caster =
      struct(MobState,
        instance_id: 10,
        owner_player_id: 20,
        hp: 345,
        x: 50,
        y: 60,
        map_name: "test_map"
      )

    caster_pid = spawn(fn -> Process.sleep(:infinity) end)
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    owner_combatant = %{unit_type: :player, unit_id: 20}
    test_pid = self()

    stub(Combat, :resolve_combatant, fn :player, 20 -> {:ok, owner_combatant} end)

    stub(Combat, :splash_targets, fn "test_map", {50, 60}, 5, ^owner_combatant ->
      [{:mob, 30}, {:mob, 31}, {:player, 20}, {:player, 21}]
    end)

    stub(UnitRegistry, :get_unit, fn
      :mob, 10 -> {:ok, {MobState, caster, caster_pid}}
      :mob, 30 -> {:ok, {MobState, struct(MobState, owner_player_id: nil), target_pid}}
      :mob, 31 -> {:ok, {MobState, struct(MobState, owner_player_id: 99), target_pid}}
    end)

    stub(TargetResolver, :resolve, fn :mob, 30 ->
      {:ok, target_pid, struct(MobState, instance_id: 30, hp: 1_000), :mob}
    end)

    stub(DamageApplication, :apply_unit_damage, fn :mob, ^target_pid, 30, 345, hit_info, 20 ->
      assert hit_info.element == :fire
      assert hit_info.skill_id == 173
      send(test_pid, :damaged_enemy)
      :ok
    end)

    stub(Combat, :knockback, fn :mob, 30, 50, 60, 3 ->
      send(test_pid, :knocked_back_enemy)
      :ok
    end)

    stub(MobSession, :apply_damage, fn ^caster_pid, 345, 20 ->
      send(test_pid, :killed_caster)
      :ok
    end)

    assert {:ok, ^caster} =
             NpcSelfdestruction.cast(caster, {:unit, caster.instance_id}, 1, definition())

    assert_received :damaged_enemy
    assert_received :knocked_back_enemy
    assert_received :killed_caster
  end

  test "an unowned caster damages players through its own faction and keeps its drops path" do
    caster =
      struct(MobState,
        instance_id: 10,
        owner_player_id: nil,
        hp: 500,
        x: 50,
        y: 60,
        map_name: "test_map"
      )

    caster_pid = spawn(fn -> Process.sleep(:infinity) end)
    player_pid = spawn(fn -> Process.sleep(:infinity) end)
    mob_combatant = %{unit_type: :mob, unit_id: 10}
    test_pid = self()

    stub(Combat, :resolve_combatant, fn :mob, 10 -> {:ok, mob_combatant} end)

    stub(Combat, :splash_targets, fn "test_map", {50, 60}, 5, ^mob_combatant ->
      [{:player, 21}]
    end)

    stub(UnitRegistry, :get_unit, fn :mob, 10 -> {:ok, {MobState, caster, caster_pid}} end)

    stub(TargetResolver, :resolve, fn :player, 21 ->
      {:ok, player_pid, %{character_id: 21}, :player}
    end)

    stub(DamageApplication, :apply_unit_damage, fn :player, ^player_pid, 21, 500, _hit_info, 10 ->
      send(test_pid, :damaged_player)
      :ok
    end)

    stub(Combat, :knockback, fn :player, 21, 50, 60, 3 -> :ok end)

    stub(MobSession, :apply_damage, fn ^caster_pid, 500, 10 ->
      send(test_pid, :killed_caster)
      :ok
    end)

    assert {:ok, ^caster} =
             NpcSelfdestruction.cast(caster, {:unit, caster.instance_id}, 1, definition())

    assert_received :damaged_player
    assert_received :killed_caster
  end

  test "is catalogued as a mob-cast self skill" do
    assert {:ok, definition} = Catalog.by_name(:npc_selfdestruction)
    assert definition.id == 173
    assert definition.target_type == :self
    assert definition.element == :fire
    assert definition.splash_radius == 5
    assert definition.knockback == 3
    assert {:ok, NpcSelfdestruction} = Catalog.active_module_for(:npc_selfdestruction)
  end

  defp definition do
    NpcSelfdestruction.definition()
  end
end
