defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsSpreadattackTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsSpreadattack
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"

  setup :setup_ets_tables
  setup :set_mimic_private

  @grenade_launcher 13_160
  @shotgun 13_155

  test "spread_area_test and spread_ratio_test: target-centred splash uses each level's radius and full ratio" do
    caster = %{character_id: 1}
    primary = %{position: {10, 11}, unit_type: :mob, unit_id: 2}
    stub(Combat, :resolve_combatant, fn 2 -> {:ok, primary} end)

    for {level, radius} <-
          Enum.with_index([1, 1, 1, 2, 2, 2, 3, 3, 3, 4], 1) |> Enum.map(fn {r, l} -> {l, r} end) do
      ratio = if GameMode.mode() == :renewal, do: 100 + 30 * level, else: 100 + 20 * (level - 1)

      expect(Combat, :execute_splash_attack, fn ^caster, {10, 11}, ^radius, opts ->
        assert opts[:skill_ratio] == ratio
        assert opts[:target_skill_units]
        assert opts[:delivery] == {:splash, {:mob, 2}}
        [2, 3]
      end)

      assert {:ok, ^caster} =
               GsSpreadattack.cast(caster, {:unit, 2}, level, GsSpreadattack.definition())
    end
  end

  test "spread_weapon_mode_test: grenade launcher gate and five bullets" do
    definition = GsSpreadattack.definition()

    assert Caster.Player.check_weapon(caster(@grenade_launcher), definition) ==
             if(GameMode.mode() == :renewal, do: :ok, else: {:error, :wrong_weapon})

    assert Caster.Player.check_weapon(caster(@shotgun), definition) == :ok

    caster = caster(@shotgun)

    assert {:ok, prepared} =
             Caster.Player.castend_cost(caster, GsSpreadattack, {:unit, 2}, definition, 1)

    {paid, remaining} = Caster.Player.commit_primary(caster, prepared)
    paid = Caster.Player.commit(paid, remaining)
    assert paid.inventory[1].amount == 1
  end

  test "spread_area_test: the primary target and every other target take the full hit" do
    primary_pid = spawn(fn -> Process.sleep(:infinity) end)
    other_pid = spawn(fn -> Process.sleep(:infinity) end)
    caster = mob_caster()
    primary = target(2, 12, 10)
    other = target(3, 13, 10)

    stub(Combat, :resolve_combatant, fn 2 ->
      {:ok, %{unit_type: :player, unit_id: 2, position: {12, 10}}}
    end)

    stub(SpatialIndex, :get_all_units_in_range, fn _map, 12, 10, _radius ->
      [{:player, 2}, {:player, 3}, {:mob, 1}]
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :player, 2 -> {:ok, {12, 10, @map}}
      :player, 3 -> {:ok, {13, 10, @map}}
    end)

    stub(UnitRegistry, :get_player_pid, fn
      2 -> {:ok, primary_pid}
      3 -> {:ok, other_pid}
      _id -> {:error, :not_found}
    end)

    stub(UnitRegistry, :get_unit, fn
      :player, 2 -> {:ok, {PlayerState, primary, primary_pid}}
      :player, 3 -> {:ok, {PlayerState, other, other_pid}}
      _type, _id -> {:error, :not_found}
    end)

    stub(DamageCalculator, :calculate_damage, fn _attacker, _target, opts ->
      assert opts[:skill_ratio] == if(GameMode.mode() == :renewal, do: 250, else: 180)
      {:ok, %{damage: 50, is_critical: false}}
    end)

    stub(HitCalculations, :calculate_hit_result, fn _attacker, _defender -> :hit end)
    stub(PacketFactory, :build_skill_damage_packet, fn _, _, _, _, _, _ -> :packet end)
    stub(Broadcast, :to_in_range, fn _, _, _, _, _ -> :ok end)

    test_pid = self()

    stub(PlayerSession, :apply_damage, fn pid, damage, _attacker, _info ->
      send(test_pid, {:damage, pid, damage})
      :ok
    end)

    assert {:ok, _caster} =
             GsSpreadattack.cast(caster, {:unit, 2}, 5, GsSpreadattack.definition())

    assert_received {:damage, ^primary_pid, 50}
    assert_received {:damage, ^other_pid, 50}
  end

  defp caster(weapon) do
    PlayerStateFixture.build(%{
      character_id: 101,
      inventory: %{1 => %InventoryItem{nameid: 13_200, amount: 6, equip: 0x008000}},
      pending_inventory_persist: [],
      stats: %{equipment: %{right_hand: weapon}}
    })
  end

  defp mob_caster do
    %{
      mob_state(1, 10, 10)
      | instance_id: 1,
        aggro_list: %{}
    }
  end

  defp target(character_id, x, y) do
    PlayerStateFixture.build(%{
      character_id: character_id,
      x: x,
      y: y,
      map_name: @map,
      stats: %{combat_stats: %CombatStats{}}
    })
  end

  defp mob_state(instance_id, x, y) do
    %MobState{
      instance_id: instance_id,
      mob_id: 1_002,
      mob_data: Aesir.TestMob.definition(),
      spawn_ref: nil,
      x: x,
      y: y,
      map_name: @map,
      hp: 100,
      sp: 50,
      spawned_at: 0
    }
    |> Aesir.TestMob.publish(max_hp: 100, max_sp: 50)
  end
end
