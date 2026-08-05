defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgNapalmbeat do
  @moduledoc """
  Napalm Beat (MG_NAPALMBEAT). Ghost-element magic that splashes a 3x3 area
  centered on the target and splits its total damage among every target hit.

  rAthena renewal: ghost element, `(70 + 10 * level)`% MATK, splash radius 1
  (3x3), damage divided evenly across the targets caught in the splash, range 9.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 11,
    name: :mg_napalmbeat,
    requires: [],
    display_name: "Napalm Beat",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :ghost,
    range: 9,
    splash_radius: 1,
    cast_time: List.duplicate(400, 10),
    fixed_cast_time: List.duplicate(100, 10),
    after_cast_delay: List.duplicate(500, 10),
    sp_cost: [9, 9, 9, 12, 12, 12, 15, 15, 15, 18]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, %{position: center}} <- Combat.resolve_combatant(target_id) do
      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: 70 + 10 * level,
        element: definition.element,
        split: true
      ]

      Combat.execute_magic_splash(caster, center, definition.splash_radius, opts)
      {:ok, caster}
    end
  end
end
