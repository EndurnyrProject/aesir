defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgFireball do
  @moduledoc """
  Fire Ball (MG_FIREBALL). Fire-element magic that splashes a 5x5 area centered
  on the target, dealing full damage to every target hit.

  rAthena renewal: fire element, `(140 + 20 * level)`% MATK, splash radius 2
  (5x5), no damage split, range 9.

  ponytail: rAthena reduces edge cells to x3/4 of the center damage. Deferred for
  v1 because `Combat.execute_magic_splash` does not expose edge-vs-center
  position; all targets take uniform full damage for now.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 17,
    name: :mg_fireball,
    requires: [],
    display_name: "Fire Ball",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :fire,
    range: 9,
    splash_radius: 2,
    cast_time: List.duplicate(800, 10),
    fixed_cast_time: List.duplicate(200, 10),
    after_cast_delay: List.duplicate(700, 10),
    sp_cost: List.duplicate(25, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, %{position: center}} <- Combat.resolve_combatant(target_id) do
      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: 140 + 20 * level,
        element: definition.element,
        split: false
      ]

      Combat.execute_magic_splash(caster, center, definition.splash_radius, opts)
      {:ok, caster}
    end
  end
end
