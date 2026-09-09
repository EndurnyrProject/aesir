defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzSightblaster do
  @moduledoc """
  Sight Blaster (WZ_SIGHTBLASTER). A self buff that answers the first enemy to step
  next to the caster with a fire strike that pushes it 3 cells.

  Renewal: 80 SP, a 1.28 s cast plus 0.32 s fixed, a 15-minute buff, and a 600% MATK
  strike. Pre-renewal: 40 SP, a 2 s cast, a 2-minute buff, and a 100% MATK strike.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 1006,
    name: :wz_sightblaster,
    display_name: "Sight Blaster",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    element: :fire,
    range: 0,
    splash_radius: 1,
    knockback: 3,
    cast_time: [renewal: [1_280], pre_renewal: [2000]],
    fixed_cast_time: [renewal: [320], pre_renewal: []],
    duration: [renewal: [900_000], pre_renewal: [120_000]],
    sp_cost: [renewal: [80], pre_renewal: [40]],
    quest_skill: true,
    quest_owner_job: :wizard

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    case StatusInterpreter.apply_status(:player, caster_id, :sc_sightblaster,
           caster_id: caster_id,
           val1: level,
           duration: hd(definition.duration)
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
