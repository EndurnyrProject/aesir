defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcRandommoveTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcRandommove
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    Mimic.copy(Cell)
    :ok
  end

  setup :verify_on_exit!

  test "requests normal mob movement to a nearby walkable cell" do
    caster =
      struct(MobState,
        instance_id: 10,
        x: 50,
        y: 60,
        map_name: "test_map"
      )

    caster_pid = spawn(fn -> Process.sleep(:infinity) end)
    test_pid = self()

    stub(Cell, :traversable?, fn "test_map", x, y -> {x, y} == {53, 58} end)
    stub(UnitRegistry, :get_unit, fn :mob, 10 -> {:ok, {MobState, caster, caster_pid}} end)

    stub(MobSession, :move_to, fn ^caster_pid, 53, 58 ->
      send(test_pid, :movement_requested)
      :ok
    end)

    assert {:ok, ^caster} = NpcRandommove.cast(caster, {:unit, 20}, 1, definition())
    assert_received :movement_requested
  end

  test "is catalogued as a mob-cast active skill" do
    assert {:ok, definition} = Catalog.by_name(:npc_randommove)
    assert definition.id == 331
    assert {:ok, NpcRandommove} = Catalog.active_module_for(:npc_randommove)
  end

  defp definition do
    NpcRandommove.definition()
  end
end
