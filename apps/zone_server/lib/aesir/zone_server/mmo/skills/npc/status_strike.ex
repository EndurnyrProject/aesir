defmodule Aesir.ZoneServer.Mmo.Skills.Npc.StatusStrike do
  @moduledoc """
  Shared `cast/4` body for the weapon-class NPC skills that also inflict a
  status on a connecting hit (`NPC_STUNATTACK`, `NPC_POISONATTACK`,
  `NPC_POISON`, `NPC_BLINDATTACK`, `NPC_CURSEATTACK`, `NPC_SILENCEATTACK`,
  `NPC_SLEEPATTACK`, `NPC_BLEEDING`).

  100% weapon-ratio hit in the skill's element; on a connecting hit it applies
  the skill's status with no explicit duration, letting the interpreter fall
  back to the status definition's own declared duration. A miss skips the
  status entirely, and a `Combat` error propagates unchanged.

  A mob caster's effective range is widened to `max(attack_range,
  skill_range)` before the attack: these skills are cast at the mob's
  configured skill range, not its melee reach.
  """

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @spec cast(struct(), integer() | Ref.t(), pos_integer(), struct(), atom()) ::
          {:ok, struct()} | {:error, atom()}
  def cast(caster, target_id, level, definition, status) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100,
      element: definition.element,
      skip_crit: true,
      report_hit: true
    ]

    case Combat.execute_skill_attack(combat_caster(caster), target_id, opts) do
      {:ok, %{hit?: true}} ->
        apply_status(caster, target_id, level, status)
        {:ok, caster}

      {:ok, %{hit?: false}} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  @spec combat_caster(struct()) :: struct()
  defp combat_caster(%MobState{mob_data: mob_data} = caster) do
    range = max(mob_data.attack_range, mob_data.skill_range)
    %{caster | mob_data: %{mob_data | attack_range: range}}
  end

  defp combat_caster(caster), do: caster

  @spec apply_status(struct(), integer() | Ref.t(), pos_integer(), atom()) :: :ok
  defp apply_status(caster, target, level, status) do
    {caster_id, source_type} = caster_ref(caster)
    {unit_type, unit_id} = target_ref(target)

    StatusInterpreter.apply_status(unit_type, unit_id, status,
      val1: level,
      caster_id: caster_id,
      source_id: caster_id,
      source_type: source_type
    )

    :ok
  end

  @spec caster_ref(struct()) :: {integer(), :mob | :player}
  defp caster_ref(%MobState{instance_id: id}), do: {id, :mob}
  defp caster_ref(%PlayerState{character_id: id}), do: {id, :player}

  @spec target_ref(integer() | Ref.t()) :: Ref.t()
  defp target_ref({unit_type, unit_id}), do: {unit_type, unit_id}

  defp target_ref(target_id) when is_integer(target_id) do
    unit_type = if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
    {unit_type, target_id}
  end
end
