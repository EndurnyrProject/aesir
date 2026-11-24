defmodule Aesir.ZoneServer.Unit.Mob.Touch do
  @moduledoc """
  NPC trigger areas for a monster: `OnTouchNPC` (rAthena `npc_touch_areanpc2`,
  run when a walk step lands).

  A cell outside every NPC trigger area and warp area of the map (the
  reference's `CELL_CHKNPC`, which ignores whether the NPC is enabled or
  visible) clears `MobState.areanpc_id`. On any other cell the map's trigger
  areas are scanned in registry order (standing in for the map's NPC order):
  a disabled or cloaked NPC is skipped (`Npc.Session.touchable?/1`; a hidden
  one still triggers), warps never move a monster (`mob_warp` 0), and the
  first area containing the monster ends the scan. That NPC fires
  `OnTouchNPC` with the monster attached unless it is the one the monster last
  fired, or it declares no such label; firing records it in `areanpc_id`.
  """

  alias Aesir.ZoneServer.Npc.Events
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @label "OnTouchNPC"

  @doc "Runs the trigger-area check for the cell the monster just stepped onto."
  @spec step(MobState.t()) :: MobState.t()
  def step(%MobState{map_name: map, x: x, y: y} = state) do
    areas =
      Enum.filter(NpcRegistry.touch_rects(map), fn {_gid, xs, ys} -> x in xs and y in ys end)

    if areas == [] and not warp_cell?(map, x, y),
      do: %{state | areanpc_id: nil},
      else: touch(state, Enum.find(areas, fn {gid, _xs, _ys} -> NpcSession.touchable?(gid) end))
  end

  defp touch(state, nil), do: state
  defp touch(%MobState{areanpc_id: gid} = state, {gid, _xs, _ys}), do: state

  defp touch(state, {gid, _xs, _ys}) do
    case Events.trigger_unit(gid, @label, {:mob, state.instance_id}) do
      :ok -> %{state | areanpc_id: gid}
      {:error, :no_handler} -> state
    end
  end

  defp warp_cell?(map, x, y) do
    case Warps.for_map(map) do
      {:ok, warps} -> Warp.Registry.hit?(warps, x, y) != nil
      :error -> false
    end
  end
end
