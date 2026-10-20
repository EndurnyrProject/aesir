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
  alias Aesir.ZoneServer.Mmo.MobSkill.Event, as: MobSkillEvent
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Ref

  @doc "Runs the closing hooks of a player's completed use of `skill_id` at `target`."
  @spec complete(PlayerState.t(), integer(), Active.target()) :: :ok
  def complete(%PlayerState{} = caster, skill_id, target) do
    with {:ok, definition} <- Catalog.by_id(skill_id),
         {:ok, on_skill_target} <- EquipProcDispatch.castend_target(definition, target) do
      if on_skill_target != nil,
        do: tell_monster({:player, caster.character_id}, skill_id, target)

      equip_on_skill(caster, skill_id, on_skill_target)
    end

    :ok
  end

  @doc """
  Runs the cast-end tail of one target of an area no-damage skill, as the
  reference's per-target re-entry into its no-damage cast end does: the
  monster skill-used event for that target and, with `on_skill: true` (a
  re-entry without the reference's area bit, Hammer Fall), the caster's
  on-skill procs for it too.

  The reference's area re-entry with the bit set (Signum Crucis, Ki
  Explosion's splash) tells the monster and stops there, since the whole
  use's requirement and on-skill tail runs once at the caster's own cast end.
  """
  @spec complete_target(PlayerState.t(), integer(), Active.target(), keyword()) :: :ok
  def complete_target(caster, skill_id, target, opts \\ []) do
    tell_monster({:player, caster.character_id}, skill_id, target)

    if Keyword.get(opts, :on_skill, false),
      do: equip_on_skill(caster, skill_id, EquipProcDispatch.hit_target(target))

    :ok
  end

  # A caster with no equipment stats has no equipment to arm.
  defp equip_on_skill(%{stats: %{}} = caster, skill_id, target) do
    EquipProcDispatch.on_skill(
      %{
        unit_id: caster.character_id,
        equip_modifiers: caster.stats.modifiers.equipment,
        equip_autobonuses: caster.stats.equip_autobonuses
      },
      skill_id,
      target
    )
  end

  defp equip_on_skill(_caster, _skill_id, _target), do: :ok

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

  defp tell_monster(source_ref, skill_id, target),
    do: MobSkillEvent.deliver_target(source_ref, {:skillused, skill_id}, target, now())

  defp now, do: System.system_time(:millisecond)
end
