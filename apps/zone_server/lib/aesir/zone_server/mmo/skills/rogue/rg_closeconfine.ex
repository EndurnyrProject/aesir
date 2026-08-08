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
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  def cast(
        %PlayerState{character_id: caster_id} = caster,
        {:unit, target_ref},
        _level,
        _definition
      ) do
    with {:ok, _pid, _target, target_type} <- TargetResolver.resolve(target_ref),
         :ok <-
           StatusInterpreter.apply_status(:player, caster_id, :sc_closeconfine2,
             val2: unit_id(target_ref),
             caster_id: caster_id,
             source_type: :player,
             duration: 10_000,
             bypass_resistance: true
           ),
         :ok <-
           StatusInterpreter.apply_status(target_type, unit_id(target_ref), :sc_closeconfine,
             val2: caster_id,
             caster_id: caster_id,
             source_type: :player,
             duration: 10_000,
             bypass_resistance: true
           ) do
      {:ok, caster}
    end
  end

  defp unit_id({_unit_type, unit_id}), do: unit_id
  defp unit_id(unit_id), do: unit_id
end
