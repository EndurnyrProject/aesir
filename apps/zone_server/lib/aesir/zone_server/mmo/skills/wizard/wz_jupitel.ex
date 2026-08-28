defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzJupitel do
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
    requires: [],
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
  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impact_delay_ms 150

  @typedoc "The target and skill level captured for the delayed impact."
  @type impact :: %{target: {:mob | :player, integer()}, skill_level: pos_integer()}

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, _definition) do
    with {:ok, %{unit_type: unit_type}} <- Combat.resolve_combatant(target_id) do
      impact = %{target: {unit_type, target_id}, skill_level: level}
      Skill.defer(__MODULE__, impact, @impact_delay_ms)
      {:ok, caster}
    end
  end

  @doc "Resolves one scheduled Jupitel Thunder impact from the caster's live session state."
  @impl Active
  @spec deferred(impact(), PlayerState.t()) :: :ok | {:error, atom()}
  def deferred(
        %{target: {unit_type, target_id}, skill_level: level},
        %{x: x, y: y, map_name: map_name} = caster
      ) do
    definition = definition()

    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100,
      hit_count: level + 2,
      element: definition.element,
      skip_range: true,
      base_distance: div(level, 2) + 2,
      origin: {x, y}
    ]

    with {:ok, {target_x, target_y, ^map_name}} <-
           SpatialIndex.get_unit_position(unit_type, target_id),
         :ok <- living_target(unit_type, target_id),
         {:ok, _map_data} <- MapCache.get(map_name),
         true <- LineOfSight.clear?(map_name, {x, y}, {target_x, target_y}),
         :ok <- Combat.execute_magic_attack(caster, target_id, opts) do
      :ok
    else
      false -> {:error, :blocked_line_of_sight}
      {:ok, {_target_x, _target_y, _other_map}} -> {:error, :different_map}
      {:error, _reason} = error -> error
    end
  end

  defp living_target(unit_type, target_id) do
    with {:ok, {_module, state, _pid}} <- UnitRegistry.get_unit(unit_type, target_id),
         true <- Unit.living?(state) do
      :ok
    else
      _ -> {:error, :target_dead}
    end
  end
end
