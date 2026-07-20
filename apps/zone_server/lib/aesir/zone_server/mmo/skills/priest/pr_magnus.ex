defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrMagnus do
  @moduledoc """
  Magnus Exorcismus (PR_MAGNUS), a persistent Holy ground field.

  The field follows rAthena's dedicated 33-cell layout and pulses every three
  seconds. Renewal damages ordinary hostile targets with base Holy magic; only
  undead and demon targets receive the source's additional 30% skill ratio.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 79,
    name: :pr_magnus,
    display_name: "Magnus Exorcismus",
    max_level: 10,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    range: 9,
    element: :holy,
    splash_radius: 3,
    hit_interval: 3_000,
    unit_duration: Enum.to_list(4_000..13_000//1_000),
    sp_cost: Enum.to_list(40..58//2),
    cast_time: List.duplicate(4_000, 10),
    fixed_cast_time: List.duplicate(1_000, 10),
    after_cast_delay: List.duplicate(1_000, 10),
    cooldown: List.duplicate(6_000, 10),
    item_cost: [%{id: 717, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @footprint [
    {-1, -3},
    {0, -3},
    {1, -3},
    {-1, -2},
    {0, -2},
    {1, -2},
    {-3, -1},
    {-2, -1},
    {-1, -1},
    {0, -1},
    {1, -1},
    {2, -1},
    {3, -1},
    {-3, 0},
    {-2, 0},
    {-1, 0},
    {0, 0},
    {1, 0},
    {2, 0},
    {3, 0},
    {-3, 1},
    {-2, 1},
    {-1, 1},
    {0, 1},
    {1, 1},
    {2, 1},
    {3, 1},
    {-1, 2},
    {0, 2},
    {1, 2},
    {-1, 3},
    {0, 3},
    {1, 3}
  ]

  # NOTE: PR_MAGNUS cannot react to rAthena's RemovedByFireRain until Fire Rain
  # exists; its implementation must destroy overlapping Magnus groups.

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: {x, y}, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: Enum.map(@footprint, fn {dx, dy} -> {x + dx, y + dy} end),
       state: %{},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       path_check: true
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{center: center, map_name: map_name, cells: cells} = group, _now) do
    definition = definition()
    footprint = MapSet.new(cells)

    case Combat.resolve_combatant(group.caster_id) do
      {:ok, caster} ->
        map_name
        |> Combat.splash_targets(center, definition.splash_radius, group.caster_id)
        |> Enum.filter(&on_footprint?(&1, footprint))
        |> Enum.each(&hit(group, definition, caster, &1))

        {:ok, group}

      {:error, _reason} ->
        {:ok, group}
    end
  end

  @spec on_footprint?({atom(), integer()}, MapSet.t({integer(), integer()})) :: boolean()
  defp on_footprint?({unit_type, target_id}, footprint) do
    case SpatialIndex.get_unit_position(unit_type, target_id) do
      {:ok, {x, y, _map_name}} -> MapSet.member?(footprint, {x, y})
      {:error, :not_found} -> false
    end
  end

  @spec hit(Group.t(), struct(), struct(), {atom(), integer()}) :: :ok
  defp hit(group, definition, caster, {unit_type, target_id}) do
    case Combat.resolve_combatant(unit_type, target_id) do
      {:ok, target} ->
        Combat.apply_skill_unit_damage(
          caster,
          unit_type,
          target_id,
          group.skill_id,
          group.level,
          definition.element,
          skill_ratio(target),
          hit_count: group.level
        )

      {:error, _reason} ->
        :ok
    end

    :ok
  end

  @spec skill_ratio(map()) :: pos_integer()
  defp skill_ratio(%{race: :demon}), do: 130

  defp skill_ratio(%{race: race} = target) do
    if RaceModifiers.undead?(race) or undead_element?(Map.get(target, :element)),
      do: 130,
      else: 100
  end

  defp undead_element?({:undead, _level}), do: true
  defp undead_element?(:undead), do: true
  defp undead_element?(_element), do: false
end
