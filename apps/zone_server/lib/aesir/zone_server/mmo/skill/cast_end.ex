defmodule Aesir.ZoneServer.Mmo.Skill.CastEnd do
  @moduledoc """
  The hooks that close a completed skill use, whether its effect succeeded or
  failed after its requirement was spent.

  A no-damage use aimed at a monster first tells that monster the skill was
  used on it (its skill-used event, delivered to its own session). A player
  caster's on-skill equipment procs then arm. Damage skills arm both from
  their damaging hits instead; a no-damage skill placed as a unit at its
  caster, and a player's Heal, Resurrection or Aspersio turned into an attack
  on an undead target, tell no monster. Only players have on-skill procs.
  """

  alias Aesir.ZoneServer.Mmo.Combat.EquipProcDispatch
  alias Aesir.ZoneServer.Mmo.MobSkill.Selector
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Runs the closing hooks of a player's completed use of `skill_id` at `target`."
  @spec complete(PlayerState.t(), integer(), Active.target()) :: :ok
  def complete(%PlayerState{} = caster, skill_id, target) do
    with {:ok, definition} <- Catalog.by_id(skill_id),
         {:ok, on_skill_target} <- EquipProcDispatch.castend_target(definition, target) do
      if on_skill_target != nil,
        do: tell_monster({:player, caster.character_id}, skill_id, target)

      EquipProcDispatch.on_skill(
        %{
          unit_id: caster.character_id,
          equip_modifiers: caster.stats.modifiers.equipment,
          equip_autobonuses: caster.stats.equip_autobonuses
        },
        skill_id,
        on_skill_target
      )
    end

    :ok
  end

  @doc """
  Runs the closing hook of a non-player caster's completed use of
  `definition` at `target`: the targeted monster's skill-used event.
  """
  @spec complete_unit(Ref.t(), Definition.t(), Active.target() | {:unit, atom(), integer()}) ::
          :ok
  def complete_unit(source_ref, %Definition{} = definition, target) do
    if Definition.cast_type(definition) == :no_damage and
         not (target_self?(source_ref, target) and EquipProcDispatch.self_unit_skill?(definition)),
       do: tell_monster(source_ref, definition.id, target)

    :ok
  end

  defp target_self?(_source_ref, :self), do: true
  defp target_self?({type, id}, {:unit, type, id}), do: true
  defp target_self?({type, id}, {:unit, {type, id}}), do: true
  defp target_self?(_source_ref, _target), do: false

  defp tell_monster(source_ref, skill_id, target) do
    with {:ok, {:mob, id}} <- monster_ref(source_ref, target),
         {:ok, {_module, _state, pid}} <- UnitRegistry.get_unit(:mob, id) do
      MobSession.skill_event(pid, source_ref, skill_used(skill_id), now())
    end

    :ok
  end

  @spec skill_used(integer()) :: Selector.event()
  defp skill_used(skill_id), do: {:skillused, skill_id}

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

  defp now, do: System.system_time(:millisecond)
end
