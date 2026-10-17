defmodule Aesir.ZoneServer.Mmo.Combat.ZeroDamageHitTest do
  @moduledoc """
  Verifies the uncalculated zero-damage weapon hit (`AutoAttack.execute_zero_damage_hit/3`):
  its delivery to the monster and the attacker's additional-effect and counter stages.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat.AutoAttack
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutocast
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnchantPoison
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(OnHitEffects)
    Mimic.copy(EquipComa)
    Mimic.copy(EnchantPoison)
    :ok
  end

  @caster_id 1_001
  @mob_id 2_001
  @cold_bolt 14
  @fire_bolt 19
  @lightning_bolt 20
  @force_target 1

  defp charm_flag, do: BattleFlags.build(:weapon, :long, false)

  defp autocast(skill_id, flag),
    do: %{
      trigger: :attack,
      skill_id: skill_id,
      level: 3,
      rate: 1_000,
      flag: flag,
      force: @force_target
    }

  defp autobonus(flag, order),
    do: %{
      trigger: :attack,
      battle_flag: flag,
      rate: 1_001,
      source_order: {0, order},
      source_identity: {:host, order + 1}
    }

  defp caster(autocasts \\ [], autobonuses \\ %{}) do
    state =
      PlayerState.new(%Character{
        id: @caster_id,
        account_id: @caster_id,
        name: "Dancer",
        class: 20,
        sex: "F",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 50,
        hp: 100,
        sp: 100
      })

    equipment = Enum.reduce(autocasts, %{}, &EquipAutocast.register(&2, &1, 0))

    state
    |> put_in([Access.key!(:stats), Access.key!(:modifiers), Access.key!(:equipment)], equipment)
    |> put_in([Access.key!(:stats), Access.key!(:equip_autobonuses)], autobonuses)
  end

  defp register_mob do
    {:ok, definition} = Mobs.by_id(1002)

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: 103, y: 100, xs: 0, ys: 0}
    }

    mob = MobState.new(@mob_id, definition, spawn, "prontera", 103, 100)
    :ok = UnitRegistry.register_unit(:mob, @mob_id, MobState, mob, self())
    mob
  end

  setup do
    test_pid = self()
    stub(UnitRegistry, :get_player_pid, fn @caster_id -> {:ok, test_pid} end)
    stub(EquipBreak, :resolve, fn _stats, _target -> [] end)
    :ok
  end

  test "delivers a connected hit of no damage to the monster without a damage packet" do
    register_mob()
    test_pid = self()
    reject(&Broadcast.to_in_range/5)

    expect(MobSession, :apply_damage, fn pid, 0, {:player, @caster_id}, metadata ->
      send(test_pid, {:delivered, pid, metadata})
      :ok
    end)

    player = caster()
    assert ^player = AutoAttack.execute_zero_damage_hit(player, @mob_id, charm_flag())

    assert_received {:delivered, ^test_pid, metadata}
    assert %{connected?: true, div: 1, skill_id: nil} = metadata
    refute Map.has_key?(metadata, :weapon_attack?)
    refute Map.has_key?(metadata, :dmg_type)
    assert %{hit_class: :hit, damage: 0, attack_flag: flag} = metadata.proc_event
    assert flag == charm_flag()
  end

  test "rolls Enchant Poison on the monster though the hit dealt nothing" do
    register_mob()
    stub(MobSession, :apply_damage, fn _pid, 0, _source, _metadata -> :ok end)
    expect(EnchantPoison, :roll_poison, fn {:player, @caster_id}, {:mob, @mob_id} -> :ok end)

    AutoAttack.execute_zero_damage_hit(caster(), @mob_id, charm_flag())
  end

  test "rolls the equipment coma for the hit of no damage" do
    register_mob()
    test_pid = self()
    expect(EquipComa, :trigger?, fn %{unit_id: @caster_id}, %{unit_id: @mob_id} -> true end)
    reject(&MobSession.apply_damage/4)

    expect(MobSession, :apply_coma, fn ^test_pid, {:player, @caster_id}, metadata ->
      send(test_pid, {:coma, metadata})
      :ok
    end)

    AutoAttack.execute_zero_damage_hit(caster(), @mob_id, charm_flag())

    assert_received {:coma, %{hit_damage: 0, connected?: true}}
  end

  test "rolls only the attack autospells and autobonuses of a ranged normal weapon hit" do
    register_mob()
    stub(MobSession, :apply_damage, fn _pid, 0, _source, _metadata -> :ok end)

    player =
      caster(
        [
          autocast(@cold_bolt, charm_flag()),
          autocast(@fire_bolt, BattleFlags.build(:weapon, :short, false)),
          autocast(@lightning_bolt, BattleFlags.build(:weapon, :long, true))
        ],
        %{
          {10, 0} => autobonus(charm_flag(), 0),
          {10, 1} => autobonus(BattleFlags.build(:misc, :long, true), 1)
        }
      )

    AutoAttack.execute_zero_damage_hit(player, @mob_id, charm_flag())

    assert_received {:"$gen_cast",
                     {:skill,
                      {:equip_proc,
                       %{skill_id: @cold_bolt, rate: 1_000, target: {:unit, @mob_id}}}}}

    refute_received {:"$gen_cast", {:skill, {:equip_proc, %{skill_id: @fire_bolt}}}}
    refute_received {:"$gen_cast", {:skill, {:equip_proc, %{skill_id: @lightning_bolt}}}}
    assert_received {:"$gen_cast", {:equipment, {:autobonus_activate, {10, 0}, {:host, 1}}}}
    refute_received {:"$gen_cast", {:equipment, {:autobonus_activate, {10, 1}, _}}}
  end

  test "runs the connected normal attack's additional effects for the hit" do
    mob = register_mob()
    stub(MobSession, :apply_damage, fn _pid, 0, _source, _metadata -> :ok end)
    flag = charm_flag()

    expect(OnHitEffects, :after_hit, fn %{unit_id: @caster_id},
                                        %{unit_id: @mob_id},
                                        stages,
                                        opts ->
      assert %{hit_class: :hit, attack_effects?: true, counter_effects?: true} = stages
      assert opts[:attack_flag] == flag
      :ok
    end)

    expect(Passives, :after_normal_hit, fn %PlayerState{character_id: @caster_id}, hit ->
      assert %{target_type: :mob, target_id: @mob_id, position: {103, 100}} = hit
      :ok
    end)

    expect(EquipBreak, :resolve, fn _stats, {:mob, ^mob} -> [] end)

    AutoAttack.execute_zero_damage_hit(caster(), @mob_id, flag)
  end

  test "a monster that is gone takes nothing" do
    reject(&MobSession.apply_damage/4)
    reject(&OnHitEffects.after_hit/4)

    player = caster()
    assert ^player = AutoAttack.execute_zero_damage_hit(player, @mob_id, charm_flag())
  end
end
