defmodule Aesir.ZoneServer.Unit.Mob.TouchTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Npc.Events
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Mob.Touch

  setup :set_mimic_from_context

  setup do
    test_pid = self()

    stub(NpcRegistry, :touch_rects, fn "prontera" -> [{1, 9..11, 9..11}, {2, 8..12, 8..12}] end)

    warp = %Warp{id: "w", map: "prontera", to_map: "izlude", x: 30, y: 30, to_x: 1, to_y: 1}
    stub(Warps, :for_map, fn "prontera" -> {:ok, [warp]} end)
    stub(NpcSession, :touchable?, fn _gid -> true end)

    stub(Events, :trigger_unit, fn gid, label, unit ->
      send(test_pid, {:fired, gid, label, unit})
      :ok
    end)

    %{mob: build(:mob_state, map_name: "prontera", x: 10, y: 10)}
  end

  test "the first area containing the mob fires OnTouchNPC once with the mob attached",
       %{mob: mob} do
    stepped = Touch.step(mob)

    assert stepped.areanpc_id == 1
    assert_received {:fired, 1, "OnTouchNPC", {:mob, id}} when id == mob.instance_id
    refute_received {:fired, 2, _label, _unit}

    assert Touch.step(%{stepped | x: 11}).areanpc_id == 1
    refute_received {:fired, _gid, _label, _unit}
  end

  test "a disabled or cloaked NPC is skipped and the next area fires", %{mob: mob} do
    stub(NpcSession, :touchable?, fn gid -> gid != 1 end)

    assert Touch.step(mob).areanpc_id == 2
    assert_received {:fired, 2, "OnTouchNPC", _unit}
  end

  test "an area without OnTouchNPC ends the scan and records nothing", %{mob: mob} do
    stub(Events, :trigger_unit, fn gid, _label, _unit ->
      send(self(), {:asked, gid})
      {:error, :no_handler}
    end)

    assert Touch.step(%{mob | areanpc_id: 7}).areanpc_id == 7
    assert_received {:asked, 1}
    refute_received {:asked, 2}
  end

  test "moving from one area to another fires the new one", %{mob: mob} do
    assert Touch.step(%{mob | x: 12, areanpc_id: 1}).areanpc_id == 2
    assert_received {:fired, 2, "OnTouchNPC", _unit}
  end

  test "only a cell outside every trigger and warp area clears the last area", %{mob: mob} do
    assert Touch.step(%{mob | x: 30, y: 30, areanpc_id: 1}).areanpc_id == 1
    assert Touch.step(%{mob | x: 50, y: 50, areanpc_id: 1}).areanpc_id == nil
    refute_received {:fired, _gid, _label, _unit}
  end

  test "an untouchable area still counts as an NPC cell", %{mob: mob} do
    stub(NpcSession, :touchable?, fn _gid -> false end)

    assert Touch.step(%{mob | areanpc_id: 1}).areanpc_id == 1
    refute_received {:fired, _gid, _label, _unit}
  end
end
