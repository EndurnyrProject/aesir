defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.SelfBuff do
  @moduledoc """
  Applies a self-targeted buff status to the casting mob (`NPC_AGIUP`,
  `SM_ENDURE`).

  Status modifiers already fold live into `MobState.to_combatant/1` (Phase 2b
  Task 1), and `StatusInterpreter.apply_status/4` itself broadcasts the status
  icon/opt display on landing, so this archetype only needs to call it — no
  extra stat recompute or effect broadcast is warranted here.

  `val1`/`val2` both scale with the row's skill level, mirroring the
  `val1 = skill_level` convention player self-buffs use (see
  `Skills.AlIncagi`, `Skills.SmEndure`). This is a flat approximation, not a
  per-level rAthena `skill_db` table.
  """

  @behaviour Aesir.ZoneServer.Mmo.MobSkill.Archetype

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @impl true
  def apply(%MobState{} = caster, {:unit, :mob, id}, params, level) do
    StatusInterpreter.apply_status(:mob, id, params.status,
      val1: level,
      val2: level,
      caster_id: caster.instance_id,
      source_id: caster.instance_id
    )
  end

  def apply(%MobState{}, _target, _params, _level), do: {:error, :invalid_target}
end
