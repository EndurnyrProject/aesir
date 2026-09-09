defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgFireball do
  @moduledoc """
  Fire Ball (MG_FIREBALL). Fire-element magic that splashes a 5x5 area centered
  on the target, dealing full damage to every target hit. Unlike Napalm Beat the
  total is not divided between the victims: every target in the blast takes the
  full amount.

  Renewal: the blast is the mage's main early nuke, `140 + 20` percent of magic
  attack per level, cast in a flat 0.8 seconds at every level with a 0.2 second
  fixed component.

  Pre-renewal: the same blast is much weaker, `70 + 10` percent per level, and
  the cast is slower and level-gated - 1.5 seconds up to level 5, 1 second from
  level 6, with the caster locked for the same span after the cast and no fixed
  cast component at all.

  In both modes the outermost ring of the blast - a victim exactly two cells from
  the centre - takes three quarters of the centre damage; the centre cell and the
  ring beside it take the full amount.
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
    cast_time: [
      renewal: List.duplicate(800, 10),
      pre_renewal: [1500, 1500, 1500, 1500, 1500, 1000, 1000, 1000, 1000, 1000]
    ],
    fixed_cast_time: List.duplicate(200, 10),
    after_cast_delay: [
      renewal: List.duplicate(700, 10),
      pre_renewal: [1500, 1500, 1500, 1500, 1500, 1000, 1000, 1000, 1000, 1000]
    ],
    sp_cost: List.duplicate(25, 10)

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @doc """
  Percentage of the caster's magic attack the blast deals at `level` in `mode`,
  for a victim `distance` cells from the centre.

  The outermost ring of the 5x5 blast keeps three quarters of the centre ratio in
  both modes; everything closer takes it whole.
  """
  @spec skill_ratio(GameMode.t(), pos_integer(), non_neg_integer()) :: pos_integer()
  def skill_ratio(mode, level, 2), do: div(centre_ratio(mode, level) * 3, 4)
  def skill_ratio(mode, level, _distance), do: centre_ratio(mode, level)

  @spec centre_ratio(GameMode.t(), pos_integer()) :: pos_integer()
  defp centre_ratio(:renewal, level), do: 140 + 20 * level
  defp centre_ratio(:pre_renewal, level), do: 70 + 10 * level

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, %{position: center}} <- Combat.resolve_combatant(target_id) do
      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: &skill_ratio(GameMode.mode(), level, &1),
        element: definition.element,
        split: false
      ]

      Combat.execute_magic_splash(caster, center, definition.splash_radius, opts)
      {:ok, caster}
    end
  end
end
