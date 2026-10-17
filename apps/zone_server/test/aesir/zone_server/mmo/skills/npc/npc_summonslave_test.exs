defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcSummonslaveTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcSummonslave
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 5001
  @map "prontera"
  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 200, 200)})
    :ok
  end

  test "summons the full requested count even with five existing slaves" do
    caster = caster()

    Enum.each(9101..9105, fn id ->
      slave = %{caster | instance_id: id, master_id: @caster_id}
      UnitRegistry.register_unit(:mob, id, MobState, slave, nil)
    end)

    expect(Coordinator, :summon_mob, 7, fn @map, 1002, x, y, opts ->
      assert Geometry.chebyshev_distance(x, y, 100, 100) <= 2
      refute {x, y} == {100, 100}
      assert opts[:master_id] == @caster_id
      {:ok, System.unique_integer([:positive])}
    end)

    assert {:ok, %{can_summon: true}} =
             NpcSummonslave.mob_cast(
               caster,
               {:unit, :mob, @caster_id},
               7,
               NpcSummonslave.definition(),
               row([val1: 1002], 7)
             )
  end

  test "cycles only the consecutive valid species prefix and the executor retains summoner state" do
    test_pid = self()

    expect(Coordinator, :summon_mob, 3, fn @map, id, _, _, _ ->
      send(test_pid, {:summoned, id})
      {:ok, id}
    end)

    assert {:ok, %{can_summon: true}} =
             Executor.execute(caster(), row([val1: 1002, val2: 1007, val3: 0, val4: 1008], 3))

    assert_received {:summoned, 1002}
    assert_received {:summoned, 1007}
    assert_received {:summoned, 1002}
    refute_received {:summoned, 1008}
  end

  test "an invalid first species is a successful no-op and players cannot cast it" do
    reject(&Coordinator.summon_mob/5)

    assert :ok =
             NpcSummonslave.mob_cast(
               caster(),
               :self,
               2,
               NpcSummonslave.definition(),
               row(val1: 0, val2: 1002)
             )

    assert {:error, :mob_only} =
             NpcSummonslave.cast(caster(), :self, 2, NpcSummonslave.definition())
  end

  defp caster do
    {:ok, data} = Mobs.by_id(1002)

    struct(MobState, %{
      instance_id: @caster_id,
      mob_data: data,
      hp: 100,
      max_hp: 100,
      base_walk_speed: data.walk_speed,
      map_name: @map,
      x: 100,
      y: 100
    })
  end

  defp row(vals, level \\ 2) do
    %{
      skill: "NPC_SUMMONSLAVE",
      skill_id: 196,
      state: :idle,
      level: level,
      rate: 10_000,
      cast_time: 0,
      delay: 0,
      cancelable: false,
      target: :self,
      condition:
        Map.merge(
          %{type: :onspawn, value: 0, val1: nil, val2: nil, val3: nil, val4: nil, val5: nil},
          Map.new(vals)
        ),
      emotion: nil
    }
  end
end
