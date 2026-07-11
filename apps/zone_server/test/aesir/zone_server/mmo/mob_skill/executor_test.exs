defmodule Aesir.ZoneServer.Mmo.MobSkill.ExecutorTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Net.SkillCasting
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.GroundNuke
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Emote
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @map "prontera"

  defp mob(overrides \\ %{}) do
    base = %{
      instance_id: 5001,
      mob_id: 1002,
      map_name: @map,
      x: 100,
      y: 100,
      target_id: 42,
      hp: 500,
      max_hp: 500,
      mob_data: mob_data()
    }

    struct(MobState, Map.merge(base, Map.new(overrides)))
  end

  defp mob_data(overrides \\ %{}) do
    base = %{id: 1002, matk: 60, attack_range: 1, skill_range: 10}
    struct(MobDefinition, Map.merge(base, Map.new(overrides)))
  end

  defp row(overrides \\ %{}) do
    base = %{
      skill: "NPC_FIREATTACK",
      skill_id: 186,
      state: :attack,
      level: 3,
      rate: 10_000,
      cast_time: 800,
      delay: 5_000,
      cancelable: false,
      target: :target,
      condition: %{type: :always},
      emotion: nil
    }

    Map.merge(base, Map.new(overrides))
  end

  defp friend_state(instance_id, mob_id, hp, dead? \\ false) do
    struct(MobState,
      instance_id: instance_id,
      mob_id: mob_id,
      hp: hp,
      max_hp: 1000,
      is_dead: dead?
    )
  end

  describe "resolve_target/2" do
    test ":target resolves to the current target player" do
      assert Executor.resolve_target(mob(), row(%{target: :target})) ==
               {:ok, {:unit, :player, 42}}
    end

    test ":target with no target errors" do
      assert Executor.resolve_target(mob(%{target_id: nil}), row(%{target: :target})) ==
               {:error, :no_target}
    end

    test ":self resolves to the caster" do
      assert Executor.resolve_target(mob(), row(%{target: :self})) == {:ok, {:unit, :mob, 5001}}
    end

    test ":master resolves to the master mob" do
      assert Executor.resolve_target(mob(%{master_id: 7001}), row(%{target: :master})) ==
               {:ok, {:unit, :mob, 7001}}
    end

    test ":master with no master errors" do
      assert Executor.resolve_target(mob(), row(%{target: :master})) == {:error, :no_master}
    end

    test ":friend resolves to the lowest-HP living mob of the same class in skill range" do
      stub(SpatialIndex, :get_units_in_range, fn :mob, @map, 100, 100, 10 ->
        [5001, 6001, 6002, 6003, 6004]
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 6001 -> {:ok, {MobState, friend_state(6001, 1002, 300), self()}}
        :mob, 6002 -> {:ok, {MobState, friend_state(6002, 1002, 100), self()}}
        :mob, 6003 -> {:ok, {MobState, friend_state(6003, 9999, 10), self()}}
        :mob, 6004 -> {:ok, {MobState, friend_state(6004, 1002, 5, true), self()}}
      end)

      assert Executor.resolve_target(mob(), row(%{target: :friend})) ==
               {:ok, {:unit, :mob, 6002}}
    end

    test ":friend excludes the caster itself and errors when no friend is around" do
      stub(SpatialIndex, :get_units_in_range, fn :mob, @map, 100, 100, 10 -> [5001] end)

      assert Executor.resolve_target(mob(), row(%{target: :friend})) == {:error, :no_friend}
    end

    test ":randomtarget resolves to a player in skill range" do
      stub(SpatialIndex, :get_units_in_range, fn :player, @map, 100, 100, 10 -> [7] end)

      assert Executor.resolve_target(mob(), row(%{target: :randomtarget})) ==
               {:ok, {:unit, :player, 7}}
    end

    test ":randomtarget errors when no player is in range" do
      stub(SpatialIndex, :get_units_in_range, fn :player, @map, 100, 100, 10 -> [] end)

      assert Executor.resolve_target(mob(), row(%{target: :randomtarget})) ==
               {:error, :no_target}
    end

    test ":around resolves to a ground cell at the caster" do
      assert Executor.resolve_target(mob(), row(%{target: :around})) ==
               {:ok, {:ground, 100, 100, :around}}
    end

    test ":around2 resolves to a ground cell at the caster" do
      assert Executor.resolve_target(mob(), row(%{target: :around2})) ==
               {:ok, {:ground, 100, 100, :around2}}
    end

    test ":around5 resolves to a ground cell at the target" do
      stub(SpatialIndex, :get_unit_position, fn :player, 42 -> {:ok, {110, 111, @map}} end)

      assert Executor.resolve_target(mob(), row(%{target: :around5})) ==
               {:ok, {:ground, 110, 111, :around5}}
    end

    test ":around5 errors when the target position is gone" do
      stub(SpatialIndex, :get_unit_position, fn :player, 42 -> {:error, :not_found} end)

      assert Executor.resolve_target(mob(), row(%{target: :around5})) == {:error, :no_target}
    end

    test ":around5 with no target errors" do
      assert Executor.resolve_target(mob(%{target_id: nil}), row(%{target: :around5})) ==
               {:error, :no_target}
    end
  end

  describe "execute/2" do
    test "dispatches an elemental nuke to Combat.execute_magic_damage with element and skill id" do
      caster = mob()

      expect(Combat, :execute_magic_damage, fn passed_caster, 42, amount, opts ->
        assert passed_caster.instance_id == caster.instance_id
        # The nuke reaches the mob's skill range, not its melee reach.
        assert passed_caster.mob_data.attack_range == 10
        assert amount == 60 * 3
        assert opts[:skill_id] == 186
        assert opts[:skill_level] == 3
        assert opts[:element] == :fire
        :ok
      end)

      assert Executor.execute(caster, row()) == :ok
    end

    test "propagates a target resolution error without dispatching" do
      reject(&Combat.execute_magic_damage/4)

      assert Executor.execute(mob(%{target_id: nil}), row()) == {:error, :no_target}
    end

    test "dispatches a ground-target skill to its archetype module" do
      caster = mob()
      test_pid = self()
      reject(&Combat.execute_magic_damage/4)

      expect(GroundNuke, :apply, fn passed_caster, {:ground, 100, 100, :around}, params, 3 ->
        assert passed_caster.instance_id == caster.instance_id
        assert params.skill == "WZ_METEOR"
        send(test_pid, :dispatched)
        :ok
      end)

      assert Executor.execute(caster, row(%{skill: "WZ_METEOR", target: :around})) == :ok
      assert_received :dispatched
    end

    test "skips a stub skill as a no-op" do
      assert Executor.execute(mob(), row(%{skill: "NPC_EMOTION", target: :self})) == :ok
    end

    test "fires the mob emote on a successfully-resolved cast when the row has one" do
      caster = mob()

      stub(Combat, :execute_magic_damage, fn _caster, _target, _amount, _opts -> :ok end)

      expect(Emote, :show, fn {:mob, instance_id}, 3 ->
        assert instance_id == caster.instance_id
        :ok
      end)

      assert Executor.execute(caster, row(%{emotion: 3})) == :ok
    end

    test "does not fire an emote when the row has none" do
      reject(&Emote.show/2)

      stub(Combat, :execute_magic_damage, fn _caster, _target, _amount, _opts -> :ok end)

      assert Executor.execute(mob(), row(%{emotion: nil})) == :ok
    end

    test "does not fire an emote when target resolution fails" do
      reject(&Emote.show/2)
      reject(&Combat.execute_magic_damage/4)

      assert Executor.execute(mob(%{target_id: nil}), row(%{emotion: 3})) == {:error, :no_target}
    end
  end

  describe "broadcast_casting/2" do
    test "broadcasts a SkillCasting packet from the caster cell" do
      test_pid = self()

      expect(Broadcast, :to_in_range, fn @map, 100, 100, range, packet ->
        assert range == Config.view_range()
        send(test_pid, {:packet, packet})
        :ok
      end)

      assert Executor.broadcast_casting(mob(), row()) == :ok

      fire = ElementModifiers.id(:fire)

      assert_received {:packet,
                       %SkillCasting{
                         src_id: 5001,
                         target_id: 42,
                         skill_id: 186,
                         property: ^fire,
                         cast_time: 800
                       }}
    end

    test "uses property 0 and target 0 for a skill without an element and no target" do
      test_pid = self()

      expect(Broadcast, :to_in_range, fn @map, 100, 100, _range, packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      caster = mob(%{target_id: nil})

      assert Executor.broadcast_casting(caster, row(%{skill: "AL_TELEPORT", target: :self})) ==
               :ok

      assert_received {:packet, %SkillCasting{target_id: 0, property: 0}}
    end
  end
end
