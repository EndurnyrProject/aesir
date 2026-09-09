defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcShower do
  @moduledoc """
  Arrow Shower (AC_SHOWER, id 47). A rain of arrows centred on the target's
  cell that hits every enemy standing in the square around it, knocks each one
  two cells straight away from the centre, and spends a single arrow for the
  whole volley. No hit can crit, and the volley carries the equipped arrow's
  element. It is aimed from nine cells away, widened by the caster's Vulture's
  Eye level.

  Renewal: the volley is the archer's main crowd hit, landing at `150 + 10`
  percent of the attack per level, and its area widens with training - a
  3x3 square up to level 5 and a 5x5 square from level 6. The caster is locked
  out of acting for a tenth of a second after the cast.

  Pre-renewal: the volley is far weaker, `75 + 5` percent per level, but its
  area never changes - it is the full 5x5 square from level 1 - and the cast
  carries no after-cast delay at all.

  The client picks a cell for this skill in the original game; here it is aimed
  at a unit and the blast is centred on that unit's cell, which reuses the
  instantaneous splash path rather than a placed ground unit.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 47,
    name: :ac_shower,
    requires: [],
    display_name: "Arrow Shower",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 9,
    vulture_range: true,
    knockback: 2,
    splash_radius: 2,
    requires_ammo: true,
    require_weapon: [:bow],
    sp_cost: List.duplicate(15, 10),
    after_cast_delay: [renewal: List.duplicate(100, 10), pre_renewal: []]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @doc "The percentage of the attack every target in the blast takes at `level`."
  @spec skill_ratio(GameMode.t(), pos_integer()) :: pos_integer()
  def skill_ratio(:renewal, level), do: 150 + 10 * level
  def skill_ratio(:pre_renewal, level), do: 75 + 5 * level

  @doc """
  The blast's radius in cells at `level`.

  Renewal trains the area up from one cell to two at level 6; pre-renewal
  always covers two.
  """
  @spec splash_radius(GameMode.t(), pos_integer()) :: pos_integer()
  def splash_radius(:renewal, level) when level <= 5, do: 1
  def splash_radius(:renewal, _level), do: 2
  def splash_radius(:pre_renewal, _level), do: 2

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, %{position: {x, y}}} <- Combat.resolve_combatant(target_id) do
      mode = GameMode.mode()

      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: skill_ratio(mode, level),
        skip_crit: true,
        base_distance: definition.knockback,
        origin: {x, y},
        native_target_types: [:mob]
      ]

      _ = Combat.execute_splash_attack(caster, {x, y}, splash_radius(mode, level), opts)
      {:ok, caster}
    end
  end
end
