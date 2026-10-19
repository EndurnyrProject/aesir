defmodule Aesir.ZoneServer.Mmo.Skill.CastEndTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat.EquipProcDispatch
  alias Aesir.ZoneServer.Mmo.Skill.CastEnd
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!

  @steal 50
  @safety_wall 12
  @fire_bolt 19
  @mob_id 2000

  setup do
    stub(UnitRegistry, :unit_type_for, fn
      @mob_id -> {:ok, :mob}
      _id -> {:ok, :player}
    end)

    stub(UnitRegistry, :get_unit, fn :mob, @mob_id -> {:ok, {MobState, %{}, self()}} end)
    :ok
  end

  defp caster, do: PlayerStateFixture.build(%{character_id: 1000, stats: %{}})

  defp definition(id) do
    {:ok, definition} = Catalog.by_id(id)
    definition
  end

  describe "complete/3" do
    test "tells the targeted monster, then arms the player's on-skill procs" do
      test_pid = self()

      expect(MobSession, :skill_event, fn ^test_pid, {:player, 1000}, {:skillused, @steal}, _ ->
        send(test_pid, :monster_told)
        :ok
      end)

      expect(EquipProcDispatch, :on_skill, fn %{unit_id: 1000}, @steal, {:unit, @mob_id} ->
        assert_received :monster_told
        :ok
      end)

      assert :ok = CastEnd.complete(caster(), @steal, {:unit, @mob_id})
    end

    test "a ground skill arms on-skill procs without a target and tells no monster" do
      reject(&MobSession.skill_event/4)
      expect(EquipProcDispatch, :on_skill, fn _wearer, @safety_wall, nil -> :ok end)

      assert :ok = CastEnd.complete(caster(), @safety_wall, {:ground, 10, 10})
    end

    test "a damage skill closes nothing at its cast end" do
      reject(&MobSession.skill_event/4)
      reject(&EquipProcDispatch.on_skill/3)

      assert :ok = CastEnd.complete(caster(), @fire_bolt, {:unit, @mob_id})
    end

    test "a no-damage skill at a player tells no monster" do
      reject(&MobSession.skill_event/4)
      expect(EquipProcDispatch, :on_skill, fn _wearer, @steal, {:unit, 3000} -> :ok end)

      assert :ok = CastEnd.complete(caster(), @steal, {:unit, 3000})
    end
  end

  describe "complete_unit/3" do
    test "a monster's no-damage skill on itself tells itself" do
      test_pid = self()

      expect(MobSession, :skill_event, fn ^test_pid, {:mob, @mob_id}, {:skillused, @steal}, _ ->
        :ok
      end)

      assert :ok =
               CastEnd.complete_unit({:mob, @mob_id}, definition(@steal), {:unit, :mob, @mob_id})
    end

    test "a monster's damage skill tells no monster at its cast end" do
      reject(&MobSession.skill_event/4)

      assert :ok =
               CastEnd.complete_unit({:mob, 7}, definition(@fire_bolt), {:unit, :mob, @mob_id})
    end
  end
end
