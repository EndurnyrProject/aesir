defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcRandommoveTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Net.SkillCasting
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcRandommove
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @map "npc_randommove_map"

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 60, 60)})
    SpatialIndex.add_unit(:mob, 7, 30, 30, @map)
    SpatialIndex.add_unit(:player, 5, 27, 30, @map)
    test_pid = self()

    stub(Broadcast, :to_in_range, fn @map, 30, 30, _range, packet ->
      send(test_pid, {:broadcast, packet})
      :ok
    end)

    :ok
  end

  test "shows a fake cast bar, keeps the trick-casting time and escapes from the target" do
    before = System.system_time(:millisecond)

    assert {:ok, moved} =
             NpcRandommove.mob_cast(mob(), {:unit, :player, 5}, 1, definition(), %{})

    assert moved.trickcasting >= before + 3_000
    assert moved.trickcasting <= System.system_time(:millisecond) + 3_000
    assert moved.can_escape
    assert moved.walk_path == for(x <- 31..38, do: {x, 30})

    fire = ElementModifiers.id(:fire)

    assert_received {:broadcast,
                     %SkillCasting{
                       src_id: 7,
                       target_id: 7,
                       x: 0,
                       y: 0,
                       skill_id: 331,
                       property: ^fire,
                       cast_time: 3_500
                     }}
  end

  test "keeps the trick cast and escape state when no cell is free" do
    block = fn x, y ->
      Cell.put(@map, x, y, :barrier, x * 1_000 + y, blocks_movement: true)
    end

    block.(31, 30)

    assert {:ok, stayed} =
             NpcRandommove.mob_cast(mob(), {:unit, :player, 5}, 1, definition(), %{})

    assert stayed.movement_state == :standing
    assert stayed.can_escape
    assert is_integer(stayed.trickcasting)
  end

  test "a target gone from the map fails the cast" do
    assert {:error, :no_target} =
             NpcRandommove.mob_cast(mob(), {:unit, :player, 99}, 1, definition(), %{})
  end

  test "only a monster casts it" do
    assert {:error, :mob_only} = NpcRandommove.cast(mob(), {:unit, 5}, 1, definition())
  end

  defp definition, do: NpcRandommove.definition()

  defp mob do
    struct(MobState,
      instance_id: 7,
      mob_id: 1142,
      map_name: @map,
      x: 30,
      y: 30,
      hp: 10,
      mob_data: Aesir.TestMob.definition(),
      last_skillcheck: System.system_time(:millisecond),
      is_dead: false
    )
    |> Aesir.TestMob.publish(max_hp: 10, walk_speed: 800)
  end
end
