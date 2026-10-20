defmodule Aesir.ZoneServer.Mmo.MobSkill.Event do
  @moduledoc """
  Delivers a monster skill event to the monster that owns it.

  The port of the reference's `mobskill_event`: the monster reacts inside its
  own process with its own skill rows, and the caller never waits. Producers
  are a completed cast (`Skill.CastEnd`), a landed battle hit
  (`Unit.Mob.HitSkillEvents`), a cast started at the monster
  (`Unit.Player.Handlers.SkillHandler`) and a ground unit whose strike
  interval runs out on it (`Skill.Unit.UnitTimer`).

  Nothing is delivered to a target that is not a monster or is the source
  itself, matching the reference's `bl->type == BL_MOB && ss != bl`.
  """

  alias Aesir.ZoneServer.Mmo.MobSkill.Selector
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Tells the monster `target_ref` that `source_ref` produced `event` on it, at
  `tick` in milliseconds. The caller decides whether a source that is the
  monster itself is excluded: the reference excludes it for its ground-unit
  tail and its battle-hit producers, and not for a no-damage cast end.
  """
  @spec deliver(Ref.t(), Selector.event(), Ref.t(), integer()) :: :ok
  def deliver(source_ref, event, {:mob, id}, tick) do
    case UnitRegistry.get_unit(:mob, id) do
      {:ok, {_module, _state, pid}} -> MobSession.skill_event(pid, source_ref, event, tick)
      {:error, _reason} -> :ok
    end
  end

  def deliver(_source_ref, _event, _target_ref, _tick), do: :ok

  @doc """
  Delivers `event` to the monster `target` names, if it names one: a typed
  unit ref, a bare monster unit id, or `:self` for a monster source (which
  then tells nobody).
  """
  @spec deliver_target(Ref.t(), Selector.event(), term(), integer()) :: :ok
  def deliver_target(source_ref, event, target, tick) do
    case monster_ref(source_ref, target) do
      {:ok, mob_ref} -> deliver(source_ref, event, mob_ref, tick)
      :none -> :ok
    end
  end

  defp monster_ref({:mob, _id} = source_ref, :self), do: {:ok, source_ref}
  defp monster_ref(_source_ref, {:unit, :mob, id}), do: {:ok, {:mob, id}}
  defp monster_ref(_source_ref, {:unit, {:mob, id}}), do: {:ok, {:mob, id}}

  defp monster_ref(_source_ref, {:unit, id}) when is_integer(id) do
    case UnitRegistry.unit_type_for(id) do
      {:ok, :mob} -> {:ok, {:mob, id}}
      _other -> :none
    end
  end

  defp monster_ref(_source_ref, _target), do: :none
end
