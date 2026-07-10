defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.SummonSlaveTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.SummonSlave
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  @caster_id 5001
  @map "prontera"

  defp caster do
    struct(MobState, %{instance_id: @caster_id, map_name: @map, x: 100, y: 100})
  end

  defp params(vals) do
    condition =
      Map.merge(
        %{type: :slavele, value: 0, val1: nil, val2: nil, val3: nil, val4: nil, val5: nil},
        Map.new(vals)
      )

    %{skill_id: 196, skill: "NPC_SUMMONSLAVE", condition: condition}
  end

  defp register_slave(instance_id, master_id, dead? \\ false) do
    state = struct(MobState, %{instance_id: instance_id, master_id: master_id, is_dead: dead?})
    UnitRegistry.register_unit(:mob, instance_id, MobState, state, nil)
  end

  defp expect_summons(count) do
    test_pid = self()

    expect(Coordinator, :summon_mob, count, fn map, mob_id, x, y, opts ->
      send(test_pid, {:summon, map, mob_id, x, y, opts})
      {:ok, System.unique_integer([:positive])}
    end)
  end

  describe "apply/4" do
    test "summons `level` slaves of the row's val id near the caster with master_id set" do
      expect_summons(2)

      assert SummonSlave.apply(caster(), {:unit, :mob, @caster_id}, params(val1: 1100), 2) == :ok

      assert_received {:summon, @map, 1100, 100, 100, [master_id: @caster_id]}
      assert_received {:summon, @map, 1100, 100, 100, [master_id: @caster_id]}
      refute_received {:summon, _, _, _, _, _}
    end

    test "cycles through multiple val ids (rAthena mob_summonslave semantics)" do
      expect_summons(3)

      params = params(val1: 1100, val2: 1101)

      assert SummonSlave.apply(caster(), {:unit, :mob, @caster_id}, params, 3) == :ok

      assert_received {:summon, @map, 1100, _, _, _}
      assert_received {:summon, @map, 1101, _, _, _}
      assert_received {:summon, @map, 1100, _, _, _}
    end

    test "summons nothing when the per-master cap is already reached" do
      Enum.each(9101..9105, &register_slave(&1, @caster_id))
      reject(&Coordinator.summon_mob/5)

      assert SummonSlave.apply(caster(), {:unit, :mob, @caster_id}, params(val1: 1100), 2) == :ok
    end

    test "summons only up to the remaining cap headroom" do
      Enum.each(9101..9104, &register_slave(&1, @caster_id))
      expect_summons(1)

      assert SummonSlave.apply(caster(), {:unit, :mob, @caster_id}, params(val1: 1100), 2) == :ok

      assert_received {:summon, @map, 1100, _, _, _}
      refute_received {:summon, _, _, _, _, _}
    end

    test "is a no-op :ok when the row carries no valid slave id" do
      reject(&Coordinator.summon_mob/5)

      assert SummonSlave.apply(caster(), {:unit, :mob, @caster_id}, params([]), 2) == :ok
      assert SummonSlave.apply(caster(), {:unit, :mob, @caster_id}, params(val1: 0), 2) == :ok
    end
  end

  describe "count_living_slaves/1" do
    test "counts only living mobs linked to the given master" do
      register_slave(9201, @caster_id)
      register_slave(9202, @caster_id, true)
      register_slave(9203, 777)
      register_slave(9204, nil)

      assert SummonSlave.count_living_slaves(@caster_id) == 1
      assert SummonSlave.count_living_slaves(777) == 1
      assert SummonSlave.count_living_slaves(123_456) == 0
    end
  end
end
