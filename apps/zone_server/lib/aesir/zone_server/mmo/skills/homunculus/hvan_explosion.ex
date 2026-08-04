defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HvanExplosion do
  @moduledoc """
  Bio Explosion stages a destructive descriptor for aggregate-local settlement.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8_016,
    name: :hvan_explosion,
    display_name: "Bio Explosion",
    max_level: 3,
    target_type: :self,
    damage_type: :damage,
    damage_kind: :misc,
    element: :neutral,
    splash_radius: 5,
    sp_cost: [1, 1, 1],
    cooldown: [1_000, 1_000, 1_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState

  @behaviour Active

  @required_intimacy 45_000
  @reset_intimacy 100
  @delay_ms 1_500

  @impl Active
  def validate(%HomunculusState{intimacy_hundredths: intimacy}, :self, _level, _definition)
      when intimacy >= @required_intimacy,
      do: :ok

  def validate(%HomunculusState{}, :self, _level, _definition),
    do: {:error, :insufficient_intimacy}

  @impl Active
  def cast(%HomunculusState{} = caster, :self, level, definition) do
    descriptor = %{
      kind: :bio_explosion,
      homunculus_id: caster.id,
      world_gid: caster.world_gid,
      map_name: caster.map_name,
      lifecycle: caster.lifecycle,
      center: {caster.x, caster.y},
      skill_id: definition.id,
      skill_level: level,
      base_damage: div(caster.max_hp * (50 + 50 * level), 100),
      radius: definition.splash_radius,
      delay_ms: @delay_ms,
      required_intimacy: @required_intimacy,
      reset_intimacy: @reset_intimacy,
      ignore_element: true,
      target_skill_units: true,
      shoot_range_los: true
    }

    {:local_effects, caster, [{:homunculus, {:schedule_bio_explosion, descriptor}}]}
  end
end
