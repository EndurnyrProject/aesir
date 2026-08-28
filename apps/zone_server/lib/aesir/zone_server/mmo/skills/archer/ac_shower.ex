defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcShower do
  @moduledoc """
  Arrow Shower (AC_SHOWER, id 47). Bow splash centered on the target plus knockback.

  Deals 100%-ratio weapon splash damage to every enemy around the target's cell,
  knocks each hit target back 2 cells, and consumes 1 arrow per cast (handled by
  the cast interpreter when `requires_ammo: true`). Splash radius scales with
  level: 1 for lv1-5, 2 for lv6-10 (rAthena SplashArea).

  rAthena targets AC_SHOWER as Ground (click a cell); we use `:target_enemy`
  centered on the target's cell to reuse the proven instantaneous
  `execute_splash_attack` path (see design rationale).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 47,
    name: :ac_shower,
    requires: [],
    display_name: "Arrow Shower",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -1,
    knockback: 2,
    requires_ammo: true,
    sp_cost: List.duplicate(15, 10),
    after_cast_delay: List.duplicate(100, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, %{position: {x, y}}} <- Combat.resolve_combatant(target_id) do
      radius = if level <= 5, do: 1, else: 2

      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: 100,
        skip_crit: true,
        base_distance: definition.knockback,
        origin: {x, y},
        native_target_types: [:mob]
      ]

      _ = Combat.execute_splash_attack(caster, {x, y}, radius, opts)
      {:ok, caster}
    end
  end
end
