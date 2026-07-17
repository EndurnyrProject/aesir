defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.StatusAttack do
  @moduledoc """
  Single-target magic damage that also inflicts a status (`NPC_STUNATTACK`,
  `NPC_POISON`, `NPC_SLEEPATTACK`, ...).

  The damage half reuses `ElementalNuke` verbatim (its range override and
  element handling), so this archetype only adds the status application on top.
  The status is applied with no explicit duration, which makes the interpreter
  fall back to the status definition's own declared duration.

  The status only lands on a connecting hit: if the nuke fails (e.g. the target
  moved out of range), its `{:error, reason}` is propagated unchanged and no
  status is applied.
  """

  @behaviour Aesir.ZoneServer.Mmo.MobSkill.Archetype

  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.ElementalNuke
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @impl true
  def apply(%MobState{} = caster, {:unit, :player, target_id} = target, params, level) do
    with :ok <- ElementalNuke.apply(caster, target, params, level) do
      StatusInterpreter.apply_status(:player, target_id, params.status,
        caster_id: caster.instance_id,
        source_id: caster.instance_id,
        source_type: :mob
      )
    end
  end

  def apply(%MobState{}, _target, _params, _level), do: {:error, :invalid_target}
end
