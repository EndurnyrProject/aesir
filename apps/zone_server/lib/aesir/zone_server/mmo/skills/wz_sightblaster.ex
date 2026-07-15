defmodule Aesir.ZoneServer.Mmo.Skills.WzSightblaster do
  @moduledoc """
  Sight Blaster (WZ_SIGHTBLASTER). Arms the caster with a long-lived reactive
  status that hits the first enemy making contact.

  Renewal rAthena data: quest skill 1006, Fire magic, level 1, 1,280ms variable
  plus 320ms fixed cast, 900-second duration, 80 SP, range 1, and knockback 3.
  Its triggered attack uses 600% MATK.
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
    range: 1,
    splash_radius: 1,
    knockback: 3,
    cast_time: [1_280],
    fixed_cast_time: [320],
    duration: [900_000],
    sp_cost: [80]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id} = caster, :self, level, _definition) do
    case StatusInterpreter.apply_status(:player, caster_id, :sc_sightblaster,
           caster_id: caster_id,
           val1: level
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
