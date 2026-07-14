defmodule Aesir.ZoneServer.Mmo.Skills.WzEarthspike do
  @moduledoc """
  Earth Spike (`WZ_EARTHSPIKE`) is a targeted Earth magic attack.

  Renewal sources: rAthena `db/re/skill_db.yml:3669-3729` defines the level,
  target, range, hits, element, timing, and SP tables; `earthspike.cpp:13-24`
  routes the skill through magic combat and raises each hit to 200% MATK.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 90,
    name: :wz_earthspike,
    display_name: "Earth Spike",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :earth,
    range: 9,
    cast_time: [800, 1400, 2000, 2600, 3200],
    fixed_cast_time: [400, 600, 800, 1000, 1200],
    after_cast_delay: [1400, 1400, 1400, 1400, 1400],
    sp_cost: [14, 18, 22, 26, 30]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(caster),
      hit_count: level,
      element: definition.element
    ]

    case Combat.execute_magic_attack(caster, target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp skill_ratio(%{character_id: caster_id}) do
    if StatusStorage.has_status?(:player, caster_id, :sc_earth_care_option), do: 1800, else: 200
  end
end
