defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcSelfdestructionTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcSelfdestruction
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(SkillAttack)
    test_pid = self()
    caster_pid = spawn(fn -> Process.sleep(:infinity) end)

    stub(SkillAttack, :execute_misc_splash, fn _caster, {50, 60}, 5, opts ->
      send(test_pid, {:splash, opts})
      []
    end)

    stub(MobSession, :apply_damage, fn pid, damage, attacker, metadata ->
      send(test_pid, {:zapped, pid, damage, attacker, metadata})
      :ok
    end)

    stub(PlayerSession, :apply_damage, fn pid, damage, attacker, metadata ->
      send(test_pid, {:zapped, pid, damage, attacker, metadata})
      :ok
    end)

    stub(StatusStorage, :has_status?, fn
      :mob, 33, :sc_hiding -> true
      _type, _id, _status -> false
    end)

    %{caster_pid: caster_pid}
  end

  describe "a monster caster" do
    test "blasts every unit and trap but a hidden one with its HP, then dies with no killer",
         %{caster_pid: caster_pid} do
      caster = mob_caster(instance_id: 10, hp: 345)
      stub(UnitRegistry, :get_unit, fn :mob, 10 -> {:ok, {MobState, caster, caster_pid}} end)

      assert {:ok, ^caster} = NpcSelfdestruction.cast(caster, {:unit, 10}, 10, definition())

      assert_received {:splash, opts}
      assert opts[:skill_level] == 10
      assert opts[:base_damage] == 345
      assert opts[:element] == :fire
      assert opts[:target_skill_units] and opts[:shoot_range_los]
      assert opts[:base_distance] == 3 and opts[:native_requires_survival]
      assert opts[:damage_source].(:mob) == {:mob, 10}

      attacker = %{unit_type: :mob, unit_id: 10}
      assert opts[:authorize].(attacker, %{unit_type: :mob, unit_id: 30})
      assert opts[:authorize].(attacker, %{unit_type: :player, unit_id: 21})
      assert opts[:authorize].(attacker, %{unit_type: :skill_unit, unit_id: 40})
      refute opts[:authorize].(attacker, %{unit_type: :mob, unit_id: 33})

      assert_received {:zapped, ^caster_pid, 345, nil, %{passive?: true}}
    end

    test "a Marine Sphere off versus ground strikes its owner's enemies and own summons only",
         %{caster_pid: caster_pid} do
      caster = mob_caster(instance_id: 10, hp: 200, owner_player_id: 20, summon_kind: :sphere)
      owner = %{unit_type: :player, unit_id: 20}

      stub(MapFlags, :versus?, fn "test_map" -> false end)
      stub(Combat, :resolve_combatant, fn :player, 20 -> {:ok, owner} end)

      stub(Targeting, :validate_enemy, fn ^owner, target ->
        if target.unit_id in [30, 31], do: :ok, else: {:error, :not_enemy}
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 10 -> {:ok, {MobState, caster, caster_pid}}
        :mob, 31 -> {:ok, {MobState, mob_caster(owner_player_id: 99), caster_pid}}
        :mob, 32 -> {:ok, {MobState, mob_caster(owner_player_id: 20), caster_pid}}
        :mob, _id -> {:ok, {MobState, mob_caster([]), caster_pid}}
      end)

      assert {:ok, ^caster} = NpcSelfdestruction.cast(caster, {:unit, 10}, 1, definition())

      assert_received {:splash, opts}
      authorize = opts[:authorize]
      assert authorize.(caster, %{unit_type: :mob, unit_id: 30})
      refute authorize.(caster, %{unit_type: :mob, unit_id: 31})
      assert authorize.(caster, %{unit_type: :mob, unit_id: 32})

      assert authorize.(caster, %{
               unit_type: :homunculus,
               unit_id: 50,
               social_root: {:player, 20}
             })

      refute authorize.(caster, %{unit_type: :player, unit_id: 21})
      assert authorize.(caster, %{unit_type: :skill_unit, unit_id: 40})
      assert opts[:damage_source].(:mob) == 20
      assert opts[:damage_source].(:player) == {:player, 20}
    end

    test "a Marine Sphere on versus ground strikes everyone", %{caster_pid: caster_pid} do
      caster = mob_caster(instance_id: 10, hp: 200, owner_player_id: 20, summon_kind: :sphere)
      stub(MapFlags, :versus?, fn "test_map" -> true end)
      stub(UnitRegistry, :get_unit, fn :mob, 10 -> {:ok, {MobState, caster, caster_pid}} end)

      assert {:ok, ^caster} = NpcSelfdestruction.cast(caster, {:unit, 10}, 1, definition())

      assert_received {:splash, opts}
      assert opts[:authorize].(caster, %{unit_type: :player, unit_id: 20})
    end
  end

  describe "a player caster" do
    setup %{caster_pid: caster_pid} do
      caster =
        struct(PlayerState,
          character_id: 20,
          map_name: "test_map",
          x: 50,
          y: 60,
          stats: %{current_state: %{hp: 777}}
        )

      stub(UnitRegistry, :get_unit, fn
        :player, 20 -> {:ok, {PlayerState, caster, caster_pid}}
        :mob, 31 -> {:ok, {MobState, mob_caster(owner_player_id: 20), caster_pid}}
        :mob, _id -> {:ok, {MobState, mob_caster([]), caster_pid}}
      end)

      %{caster: caster}
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
      assert opts[:damage_source] == nil

      authorize = opts[:authorize]
      attacker = %{unit_type: :player, unit_id: 20}
      assert authorize.(attacker, %{unit_type: :mob, unit_id: 30})
      assert authorize.(attacker, %{unit_type: :mob, unit_id: 31})

      assert authorize.(attacker, %{
               unit_type: :homunculus,
               unit_id: 32,
               social_root: {:player, 20}
             })

      assert authorize.(attacker, %{unit_type: :skill_unit, unit_id: 40})
      refute authorize.(attacker, %{unit_type: :player, unit_id: 21})
      refute authorize.(attacker, %{unit_type: :mob, unit_id: 33})

      assert_received {:zapped, ^caster_pid, 777, nil, %{passive?: true}}
    end

    test "strikes every unit but a hidden one on versus ground", %{caster: caster} do
      stub(MapFlags, :versus?, fn "test_map" -> true end)

      assert {:ok, ^caster} = NpcSelfdestruction.cast(caster, :self, 1, definition())

      assert_received {:splash, opts}
      attacker = %{unit_type: :player, unit_id: 20}
      assert opts[:authorize].(attacker, %{unit_type: :player, unit_id: 21})
      refute opts[:authorize].(attacker, %{unit_type: :mob, unit_id: 33})
    end
  end

  defp mob_caster(fields) do
    struct(MobState, Keyword.merge([map_name: "test_map", x: 50, y: 60], fields))
  end

  defp definition, do: NpcSelfdestruction.definition()
end
