defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcRandommove do
  @moduledoc """
  NPC Random Move (NPC_RANDOMMOVE).

  A monster-only fake cast: the monster keeps a trick-casting time three skill
  intervals ahead and shows a cast bar on itself for that time plus half an
  interval, becomes unstoppable by damage until a walk ends, and runs up to
  eight cells straight away from its target (`MovementHandler.escape/3`).
  Speed Up ends the trick cast.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 331,
    name: :npc_randommove,
    requires: [],
    display_name: "NPC Random Move",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 0,
    is_npc: true,
    damage_kind: :none

  alias Aesir.Net.SkillCasting
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @behaviour Active

  @skill_interval 1000
  @trick_time @skill_interval * 3
  @escape_distance 8

  @impl Active
  def cast(_caster, _target, _level, _definition), do: {:error, :mob_only}

  @impl Active
  def mob_cast(%MobState{} = caster, {:unit, unit_type, unit_id}, _level, definition, _row) do
    with {:ok, target_cell} <- target_cell(caster, unit_type, unit_id) do
      now = System.system_time(:millisecond)
      show_trick_cast(caster, definition)

      {:ok,
       %{caster | trickcasting: now + @trick_time, can_escape: true}
       |> MovementHandler.escape(target_cell, @escape_distance)}
    end
  end

  defp target_cell(%MobState{instance_id: id, x: x, y: y}, :mob, id), do: {:ok, {x, y}}

  defp target_cell(_caster, unit_type, unit_id) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {x, y, _map}} -> {:ok, {x, y}}
      {:error, :not_found} -> {:error, :no_target}
    end
  end

  defp show_trick_cast(%MobState{} = caster, definition) do
    packet = %SkillCasting{
      src_id: caster.instance_id,
      target_id: caster.instance_id,
      x: 0,
      y: 0,
      skill_id: definition.id,
      property: ElementModifiers.id(:fire),
      cast_time: @trick_time + div(@skill_interval, 2)
    }

    Broadcast.to_in_range(caster.map_name, caster.x, caster.y, Config.view_range(), packet)
  end
end
