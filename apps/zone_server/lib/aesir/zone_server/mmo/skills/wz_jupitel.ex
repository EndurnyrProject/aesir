defmodule Aesir.ZoneServer.Mmo.Skills.WzJupitel do
  @moduledoc """
  Jupitel Thunder (WZ_JUPITEL). Targeted Wind magic with level-dependent hits
  and knockback.

  Renewal data comes from rAthena `db/re/skill_db.yml:3202-3302`: skill 84,
  range 9, 3-12 hits, 2-7 cells of knockback, 2,000-3,800ms variable cast,
  500ms fixed cast, and 20-47 SP. Each hit uses the default 100% MATK ratio.
  The delayed attack is defined by `skills/mage/jupitelthunder.cpp:9-12`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 84,
    name: :wz_jupitel,
    display_name: "Jupitel Thunder",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :wind,
    range: 9,
    cast_time: [2000, 2200, 2400, 2600, 2800, 3000, 3200, 3400, 3600, 3800],
    fixed_cast_time: List.duplicate(500, 10),
    sp_cost: [20, 23, 26, 29, 32, 35, 38, 41, 44, 47]

  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @impact_delay_ms 150

  @typedoc "The target and skill level captured for the delayed impact."
  @type impact :: %{target: {:mob | :player, integer()}, skill_level: pos_integer()}

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, _definition) do
    with {:ok, %{unit_type: unit_type}} <- Combat.resolve_combatant(target_id) do
      impact = %{target: {unit_type, target_id}, skill_level: level}
      Process.send_after(self(), {:jupitel_impact, impact}, @impact_delay_ms)
      {:ok, caster}
    end
  end

  @doc "Resolves one scheduled Jupitel Thunder impact from the caster's live session state."
  @spec impact(PlayerState.t(), impact()) :: :ok | {:error, atom()}
  def impact(
        %{x: x, y: y, map_name: map_name} = caster,
        %{target: {unit_type, target_id}, skill_level: level}
      ) do
    definition = definition()

    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100,
      hit_count: level + 2,
      element: definition.element,
      skip_range: true
    ]

    with {:ok, {target_x, target_y, ^map_name}} <-
           SpatialIndex.get_unit_position(unit_type, target_id),
         {:ok, _map_data} <- MapCache.get(map_name),
         true <- LineOfSight.clear?(map_name, {x, y}, {target_x, target_y}),
         :ok <- Combat.execute_magic_attack(caster, target_id, opts) do
      _ = Combat.knockback(unit_type, target_id, x, y, div(level, 2) + 2)
      :ok
    else
      false -> {:error, :blocked_line_of_sight}
      {:ok, {_target_x, _target_y, _other_map}} -> {:error, :different_map}
      {:error, _reason} = error -> error
    end
  end
end
