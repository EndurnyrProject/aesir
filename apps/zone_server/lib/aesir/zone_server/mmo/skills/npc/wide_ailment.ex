defmodule Aesir.ZoneServer.Mmo.Skills.Npc.WideAilment do
  @moduledoc """
  Resolves the NPC wide ailments around the cast's target unit.

  Living enemies in the square are affected without a wall check, including
  units sharing the center cell. Every recipient makes its ordinary status
  defense against a 100% base chance. Player casts use their session's normal
  skill visual; other casters broadcast the no-damage effect here.
  """

  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast

  @doc "Applies the declared ailment to the target-centered enemy square."
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, :self, level, definition) do
    adapter = Caster.for(caster)
    cast(caster, {:unit, {adapter.unit_type(caster), adapter.id(caster)}}, level, definition)
  end

  def cast(caster, {:unit, target}, level, definition) do
    adapter = Caster.for(caster)
    source = {adapter.unit_type(caster), adapter.id(caster)}

    with {:ok, {cx, cy, map_name}} <- center(caster, source, target),
         true <- map_name == caster.map_name do
      combatant = caster.__struct__.to_combatant(caster)
      radius = Definition.splash_radius_at_level(definition, level)
      duration = Enum.at(definition.duration, level - 1, List.last(definition.duration))

      for {type, id} <- Combat.splash_targets(map_name, {cx, cy}, radius, combatant) do
        StatusInterpreter.apply_status(type, id, definition.status,
          val1: level,
          val2: combatant.unit_id,
          duration: duration,
          success_rate: 100,
          caster_id: combatant.unit_id,
          source_type: combatant.unit_type
        )
      end

      if combatant.unit_type != :player do
        Broadcast.to_in_range(map_name, cx, cy, Config.view_range(), %SkillEffect{
          skill_id: definition.id,
          level: level,
          src_id: combatant.unit_id,
          target_id: target_id(target),
          result: 1
        })
      end

      {:ok, caster}
    else
      false -> {:error, :invalid_target}
      {:error, _reason} = error -> error
    end
  end

  defp center(caster, {type, id}, target) when target == id or target == {type, id},
    do: {:ok, {caster.x, caster.y, caster.map_name}}

  defp center(_caster, _source, target) do
    case Combat.resolve_target_position(target) do
      {:ok, _type, position} -> {:ok, position}
      {:error, _reason} = error -> error
    end
  end

  defp target_id({_type, id}), do: id
  defp target_id(id), do: id
end
