defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsSpreadattack do
  @moduledoc """
  Spread Attack hits enemies and enemy traps around its target with weapon-element
  damage. Renewal deals 100 + 30 percent per level; pre-renewal deals 100 percent
  plus 20 percent per level after the first. Both consume five bullets. Renewal
  allows grenade launchers and has a one-second after-cast delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 520,
    name: :gs_spreadattack,
    display_name: "Spread Attack",
    max_level: 10,
    requires: [],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: -9,
    snake_eye_range: true,
    element: :weapon,
    splash_radius: [1, 1, 1, 2, 2, 2, 3, 3, 3, 4],
    damage_splash: true,
    require_weapon: [renewal: [:shotgun, :grenade], pre_renewal: [:shotgun]],
    require_ammo: [:bullet],
    ammo_qty: List.duplicate(5, 10),
    sp_cost: [
      renewal: Enum.map(0..9, &(13 + 3 * &1)),
      pre_renewal: Enum.map(0..9, &(15 + 5 * &1))
    ],
    after_cast_delay: [renewal: List.duplicate(1000, 10), pre_renewal: []]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target}, level, definition) do
    with :ok <- strike(caster, target, level, definition), do: {:ok, caster}
  end

  @impl Active
  def mob_cast(%MobState{} = caster, {:unit, type, id}, level, definition, _row),
    do: strike(caster, {type, id}, level, definition)

  defp strike(caster, target, level, definition) do
    with {:ok, %{position: {x, y}} = primary} <- Combat.resolve_combatant(target) do
      ratio =
        case GameMode.mode() do
          :renewal -> 100 + 30 * level
          :pre_renewal -> 100 + 20 * (level - 1)
        end

      _ =
        Combat.execute_splash_attack(
          caster,
          {x, y},
          Definition.splash_radius_at_level(definition, level),
          skill_id: definition.id,
          skill_level: level,
          skill_ratio: ratio,
          skip_crit: true,
          target_skill_units: true,
          delivery: {:splash, {primary.unit_type, primary.unit_id}}
        )

      :ok
    end
  end
end
