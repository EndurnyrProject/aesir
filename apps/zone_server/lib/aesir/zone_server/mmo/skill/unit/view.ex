defmodule Aesir.ZoneServer.Mmo.Skill.Unit.View do
  @moduledoc "Maps authoritative skill-unit state to wire messages."

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.SkillUnitCellState
  alias Aesir.Net.SkillUnitGroupState
  alias Aesir.Net.SkillUnitSnapshot
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState

  @doc "Builds a complete wire state for one skill-unit group."
  @spec group(Group.t(), [Cell.t()]) :: SkillUnitGroupState.t()
  def group(%Group{} = group, cells) do
    clock = {System.monotonic_time(:millisecond), ServerTick.now()}
    group(group, cells, clock)
  end

  @doc false
  @spec group(Group.t(), [Cell.t()], {integer(), ServerTick.t()}) :: SkillUnitGroupState.t()
  def group(%Group{} = group, cells, clock) do
    %SkillUnitGroupState{
      group_id: group.group_id,
      skill_id: group.skill_id,
      skill_level: group.level,
      owner_type: owner_type(group.caster_type),
      owner_id: group.caster_id,
      center_x: elem(group.center, 0),
      center_y: elem(group.center, 1),
      created_tick: to_server_tick(group.created_at, clock),
      expires_tick: to_server_tick(group.expires_at, clock),
      cells: cells |> Enum.sort_by(& &1.cell_id) |> Enum.map(&cell/1),
      phase: phase(group.state)
    }
  end

  @doc "Builds an authoritative replacement snapshot from complete group states."
  @spec snapshot([{Group.t(), [Cell.t()]}], non_neg_integer()) :: SkillUnitSnapshot.t()
  def snapshot(groups, server_tick) do
    clock = {System.monotonic_time(:millisecond), ServerTick.now()}

    %SkillUnitSnapshot{
      server_tick: server_tick,
      groups:
        groups
        |> Enum.sort_by(fn {group, _cells} -> group.group_id end)
        |> Enum.map(fn {group, cells} -> group(group, cells, clock) end)
    }
  end

  @doc "Builds a cell's wire state."
  @spec cell(Cell.t()) :: SkillUnitCellState.t()
  def cell(%Cell{} = cell) do
    %SkillUnitCellState{
      cell_id: cell.cell_id,
      x: cell.x,
      y: cell.y,
      hp: cell.hp,
      max_hp: cell.max_hp,
      flags: cell.flags
    }
  end

  defp phase(%{trap: %TrapState{phase: :used}}), do: :SKILL_UNIT_PHASE_USED
  defp phase(%{trap: %TrapState{phase: :sprung}}), do: :SKILL_UNIT_PHASE_SPRUNG
  defp phase(%{trap: %TrapState{phase: :captured}}), do: :SKILL_UNIT_PHASE_CAPTURED
  defp phase(_state), do: :SKILL_UNIT_PHASE_ACTIVE

  defp owner_type(:player), do: :SKILL_UNIT_OWNER_TYPE_PLAYER
  defp owner_type(:mob), do: :SKILL_UNIT_OWNER_TYPE_MOB
  defp owner_type(:npc), do: :SKILL_UNIT_OWNER_TYPE_NPC
  defp owner_type(_), do: :SKILL_UNIT_OWNER_TYPE_UNSPECIFIED

  defp to_server_tick(timestamp, {monotonic_now, server_tick})
       when is_integer(timestamp) and is_integer(monotonic_now) do
    ServerTick.add(server_tick, timestamp - monotonic_now)
  end

  defp to_server_tick(nil, {_monotonic_now, server_tick}), do: server_tick
end
