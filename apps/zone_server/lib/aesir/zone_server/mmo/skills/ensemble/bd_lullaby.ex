defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdLullaby do
  @moduledoc "Lullaby (BD_LULLABY)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 306,
    name: :bd_lullaby,
    display_name: "Lullaby",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    splash_radius: 4,
    sp_cost: [40],
    duration: [60_000],
    cast_time: [1_000],
    fixed_cast_time: [500],
    after_cast_delay: [300],
    cooldown: [20_000],
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Ensemble

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform

  @impl Active
  def cast(caster, :self, level, definition) do
    Perform.perform(caster, definition, level, :sc_sleep, fn _ -> [success_rate: 100] end,
      scope: :enemy
    )
  end
end
