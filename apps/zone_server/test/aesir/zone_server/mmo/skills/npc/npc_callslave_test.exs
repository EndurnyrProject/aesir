defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcCallslaveTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcCallslave
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 5002
  @map "prontera"
  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 200, 200)})
    :ok
  end

  test "the executor recalls existing linked slaves and never summons new monsters" do
    register_slave(10, @caster_id, @map)
    register_slave(11, 999, @map)
    register_slave(12, @caster_id, "elsewhere")
    reject(&Coordinator.summon_mob/5)

    assert :ok = Executor.execute(caster(), row())
    assert_received {:"$gen_cast", {:movement, {:warp, @map, x, y}}}
    assert Geometry.chebyshev_distance(x, y, 150, 120) <= 2
    refute_received {:"$gen_cast", {:movement, _}}
  end

  test "no slaves is a successful no-op regardless of row species values" do
    reject(&Coordinator.summon_mob/5)
    assert :ok = NpcCallslave.mob_cast(caster(), :self, 1, NpcCallslave.definition(), row())
    refute_received {:"$gen_cast", {:movement, _}}
    assert {:error, :mob_only} = NpcCallslave.cast(caster(), :self, 1, NpcCallslave.definition())
  end

  defp caster do
    struct(MobState, %{instance_id: @caster_id, map_name: @map, x: 150, y: 120})
  end

  defp register_slave(id, master_id, map) do
    slave =
      struct(MobState, %{
        instance_id: id,
        master_id: master_id,
        map_name: map,
        x: 160,
        y: 120,
        hp: 100,
        max_hp: 100
      })

    UnitRegistry.register_unit(:mob, id, MobState, slave, self())
    SpatialIndex.add_unit(:mob, id, 160, 120, map)
  end

  defp row do
    %{
      skill: "NPC_CALLSLAVE",
      skill_id: 352,
      state: :idle,
      level: 1,
      rate: 10_000,
      cast_time: 0,
      delay: 0,
      cancelable: false,
      target: :self,
      condition: %{type: :always, value: 0, val1: 1002},
      emotion: nil
    }
  end
end
