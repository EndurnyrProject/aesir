defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgNapalmbeat do
  @moduledoc """
  Napalm Beat (MG_NAPALMBEAT). Ghost-element magic that splashes a 3x3 area
  centered on the target and splits its total damage among every target hit.

  The blast is worth `70 + 10` percent of magic attack per level in both modes,
  and in both modes the total is divided evenly between the victims, so it is
  strongest against a single target and weakest in a crowd.

  Renewal casts it in a flat 0.4 seconds of variable time plus a 0.1 second
  fixed component and locks the caster for half a second afterwards at every
  level.

  Pre-renewal casts it in a flat 1 second of purely variable time, and the
  aftercast lock shrinks as the skill is levelled, from 1 second down to half a
  second, so levelling it buys cast rate rather than damage.
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
    cast_time: [renewal: List.duplicate(400, 10), pre_renewal: List.duplicate(1000, 10)],
    fixed_cast_time: List.duplicate(100, 10),
    after_cast_delay: [
      renewal: List.duplicate(500, 10),
      pre_renewal: [1000, 1000, 1000, 900, 900, 800, 800, 700, 600, 500]
    ],
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
