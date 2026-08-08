defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgCloseconfine do
  use Aesir.ZoneServer.Mmo.Skill,
    id: 1005,
    name: :rg_closeconfine,
    requires: [],
    display_name: "Close Confine",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 1,
    quest_skill: true,
    quest_owner_job: :rogue

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_ref}, _level, _definition) do
    {caster_type, caster_id} = caster_identity(caster)
    target_id = unit_id(target_ref)

    with {:ok, _pid, _target, target_type} <- TargetResolver.resolve(target_ref),
         :ok <-
           StatusInterpreter.apply_status(caster_type, caster_id, :sc_closeconfine2,
             val2: target_id,
             caster_id: caster_id,
             source_type: caster_type,
             duration: 10_000,
             bypass_resistance: true
           ),
         :ok <-
           StatusInterpreter.apply_status(target_type, target_id, :sc_closeconfine,
             val2: caster_id,
             caster_id: caster_id,
             source_type: caster_type,
             duration: 10_000,
             bypass_resistance: true
           ) do
      {:ok, caster}
    end
  end

  # Generic caster identity so the confine works for a mob caster (RG_CLOSECONFINE
  # is an imported mob skill, e.g. Drosera/Gertie) as well as a player.
  defp caster_identity(%MobState{instance_id: id}), do: {:mob, id}
  defp caster_identity(%{character_id: id}), do: {:player, id}

  defp unit_id({_unit_type, unit_id}), do: unit_id
  defp unit_id(unit_id), do: unit_id
end
