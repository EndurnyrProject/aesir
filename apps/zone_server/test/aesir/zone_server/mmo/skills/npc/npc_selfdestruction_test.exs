defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcSelfdestructionTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcSelfdestruction
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    Mimic.copy(DamageApplication)
    Mimic.copy(MobState)

    stub(MobState, :to_combatant, fn state -> %{unit_type: :mob, unit_id: state.instance_id} end)

    stub(PlayerState, :to_combatant, fn state ->
      %{unit_type: :player, unit_id: state.character_id}
    end)

    stub(MiscDamageCalculator, :calculate_misc_damage, fn _attacker, _defender, opts ->
      {:ok, %{damage: opts[:base_damage], is_critical: false}}
    end)

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
      {:ok, player_pid, struct(PlayerState, character_id: 21), :player}
    end)

    stub(DamageApplication, :apply_unit_damage, fn :player,
                                                   ^player_pid,
                                                   21,
                                                   500,
                                                   _hit_info,
                                                   {:mob, 10} ->
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

  test "each victim takes misc Fire damage adjusted by its own element" do
    caster =
      struct(MobState,
        instance_id: 10,
        owner_player_id: nil,
        hp: 400,
        x: 50,
        y: 60,
        map_name: "m"
      )

    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    test_pid = self()

    stub(Combat, :resolve_combatant, fn :mob, 10 -> {:ok, %{unit_type: :mob, unit_id: 10}} end)
    stub(Combat, :splash_targets, fn "m", {50, 60}, 5, _combatant -> [{:player, 21}] end)
    stub(UnitRegistry, :get_unit, fn :mob, 10 -> {:error, :not_found} end)

    stub(TargetResolver, :resolve, fn :player, 21 ->
      {:ok, target_pid, struct(PlayerState, character_id: 21), :player}
    end)

    stub(MiscDamageCalculator, :calculate_misc_damage, fn %{unit_id: 10}, %{unit_id: 21}, opts ->
      assert opts[:base_damage] == 400
      assert opts[:element] == :fire
      assert opts[:skill_id] == 173

      assert opts[:attack_flag] in [
               BattleFlags.build(:misc, :short, true),
               BattleFlags.build(:misc, :long, true)
             ]

      {:ok, %{damage: 600, is_critical: false}}
    end)

    stub(DamageApplication, :apply_unit_damage, fn :player,
                                                   ^target_pid,
                                                   21,
                                                   600,
                                                   hit_info,
                                                   _src ->
      send(test_pid, {:hit, hit_info.dmg_type})
      :ok
    end)

    stub(Combat, :knockback, fn :player, 21, 50, 60, 3 -> :ok end)

    assert {:ok, ^caster} =
             NpcSelfdestruction.cast(caster, {:unit, caster.instance_id}, 1, definition())

    assert_received {:hit, :misc}
  end

  describe "a player caster" do
    setup do
      Mimic.copy(SkillAttack)

      caster =
        struct(PlayerState,
          character_id: 20,
          map_name: "test_map",
          x: 50,
          y: 60,
          stats: %{current_state: %{hp: 777}}
        )

      test_pid = self()
      caster_pid = spawn(fn -> Process.sleep(:infinity) end)

      stub(SkillAttack, :execute_misc_splash, fn ^caster, {50, 60}, 5, opts ->
        send(test_pid, {:splash, opts})
        []
      end)

      stub(UnitRegistry, :get_unit, fn :player, 20 -> {:ok, {PlayerState, caster, caster_pid}} end)

      stub(PlayerSession, :apply_damage, fn pid, damage, attacker, metadata ->
        send(test_pid, {:zapped, pid, damage, attacker, metadata})
        :ok
      end)

      stub(StatusStorage, :has_status?, fn
        :mob, 33, :sc_hiding -> true
        _type, _id, _status -> false
      end)

      %{caster: caster, caster_pid: caster_pid}
    end

    test "strikes enemies, its own summons and traps off versus ground, then dies with no killer",
         %{caster: caster, caster_pid: caster_pid} do
      stub(MapFlags, :versus?, fn "test_map" -> false end)

      stub(Targeting, :validate_enemy, fn _attacker, target ->
        if target.unit_id == 30, do: :ok, else: {:error, :not_enemy}
      end)

      assert {:ok, ^caster} = NpcSelfdestruction.cast(caster, :self, 1, definition())

      assert_received {:splash, opts}
      assert opts[:base_damage] == 777
      assert opts[:element] == :fire
      assert opts[:target_skill_units] and opts[:shoot_range_los]
      assert opts[:base_distance] == 3 and opts[:native_requires_survival]

      authorize = opts[:authorize]
      attacker = %{unit_type: :player, unit_id: 20}
      assert authorize.(attacker, %{unit_type: :mob, unit_id: 30, proc_owner_id: nil})
      assert authorize.(attacker, %{unit_type: :mob, unit_id: 31, proc_owner_id: 20})

      assert authorize.(attacker, %{
               unit_type: :homunculus,
               unit_id: 32,
               social_root: {:player, 20}
             })

      assert authorize.(attacker, %{unit_type: :skill_unit, unit_id: 40})
      refute authorize.(attacker, %{unit_type: :player, unit_id: 21})
      refute authorize.(attacker, %{unit_type: :mob, unit_id: 33, proc_owner_id: nil})

      assert_received {:zapped, ^caster_pid, 777, nil, %{passive?: true}}
    end

    test "strikes every unit but a hidden one on versus ground", %{caster: caster} do
      stub(MapFlags, :versus?, fn "test_map" -> true end)
      stub(Targeting, :validate_enemy, fn _attacker, _target -> {:error, :not_enemy} end)

      assert {:ok, ^caster} = NpcSelfdestruction.cast(caster, :self, 1, definition())

      assert_received {:splash, opts}
      attacker = %{unit_type: :player, unit_id: 20}
      assert opts[:authorize].(attacker, %{unit_type: :player, unit_id: 21})
      refute opts[:authorize].(attacker, %{unit_type: :mob, unit_id: 33, proc_owner_id: nil})
    end
  end

  defp definition do
    NpcSelfdestruction.definition()
  end
end
