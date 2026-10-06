defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfFogwall do
  @moduledoc """
  Blinding Mist (PF_FOGWALL). A 5x3 fog lasting 20 s, at most two per caster.
  Cells that would fall on a Volcano or Violent Gale are not raised; cells over
  a Deluge last 40 s while the rest end at 20 s. A fog with no cell left still
  spends the cast.

  Everyone inside holds `:sc_fogwall`. An enemy entering the fog, or standing
  in it when it is raised, is blinded for 10 s unless it stands in a Deluge;
  that Blind does not run out while the unit stays in the fog (see
  `Effects.FogWall`).

  Identical in both modes: 25 SP, range 9.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 404,
    name: :pf_fogwall,
    requires: [],
    display_name: "Blinding Mist",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :magic,
    element: :earth,
    range: 9,
    sp_cost: List.duplicate(25, 5),
    unit_duration: List.duplicate(20_000, 5),
    target_hidden: true

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @blind_ms 10_000
  @blockers [:sa_volcano, :sa_violentgale]
  @doublers [:sa_deluge]

  @doc """
  Raises the fog and blinds the enemies already standing in it. A fog whose
  every cell is blocked still completes the cast.
  """
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, term()}
  def cast(caster, {:ground, x, y}, level, _definition) do
    case Unit.place(caster, :pf_fogwall, level, {x, y}) do
      {:ok, group} ->
        Enum.each(occupants(group), &blind_entrant(group, &1))
        {:ok, caster}

      {:error, :no_walkable_cells} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: {cx, cy}, map_name: map, level: level}) do
    base = Enum.at(definition().unit_duration, level - 1)

    cells =
      for dx <- -2..2,
          dy <- -1..1,
          cell = {cx + dx, cy + dy},
          not over?(map, cell, @blockers),
          do: cell

    {long, short} = Enum.split_with(cells, &over?(map, &1, @doublers))

    timing =
      if long == [] or short == [],
        do: %{state: %{}, interval: base, duration: if(long == [], do: base, else: base * 2)},
        else: %{
          state: %{short_cells: short},
          interval: base,
          initial_delay: base,
          duration: base * 2
        }

    {:ok,
     Map.merge(timing, %{
       cells: cells,
       lifecycle_policy: %LifecyclePolicy{max_instances_per_caster: 2}
     })}
  end

  @impl Ground
  @spec schedule(Group.t(), (pos_integer() -> non_neg_integer())) :: {:ok, Group.t()}
  def schedule(%Group{state: %{short_cells: _}} = group, _rng), do: {:ok, group}
  def schedule(%Group{} = group, _rng), do: {:ok, %{group | next_tick_at: nil}}

  @impl Ground
  @spec on_interval(Group.t(), integer()) ::
          {:ok, Group.t()} | {:ok, Group.t(), {:remove_cells, [Group.cell()]}}
  def on_interval(%Group{state: %{short_cells: short} = state} = group, _now),
    do: {:ok, %{group | state: Map.delete(state, :short_cells)}, {:remove_cells, short}}

  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec field_support(Group.t()) :: map()
  def field_support(%Group{}),
    do: %{status_type: :sc_fogwall, params: [], target?: fn _unit -> true end}

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()}
  def on_touch(%Group{} = group, mover) do
    blind_entrant(group, mover)
    {:ok, group}
  end

  # A unit already holding the fog status came in from another fog cell and is
  # not blinded again.
  defp blind_entrant(group, {type, id} = mover) do
    if not StatusStorage.has_status?(type, id, :sc_fogwall) and enemy?(group, mover) and
         not StatusStorage.has_status?(type, id, :sc_deluge) do
      StatusInterpreter.apply_status(type, id, :sc_blind,
        duration: @blind_ms,
        caster_id: group.caster_id,
        source_type: group.caster_type
      )
    end
  end

  defp occupants(%Group{map_name: map, cells: cells}) do
    {xs, ys} = Enum.unzip(cells)

    for type <- [:player, :mob, :homunculus],
        id <-
          SpatialIndex.get_units_in_area(
            type,
            map,
            Enum.min(xs),
            Enum.min(ys),
            Enum.max(xs),
            Enum.max(ys)
          ),
        {:ok, {x, y, ^map}} = SpatialIndex.get_unit_position(type, id),
        {x, y} in cells,
        do: {type, id}
  end

  defp over?(map, {x, y}, skill_names) do
    map |> Storage.get_groups_at_cell(x, y) |> Enum.any?(&(&1.skill_name in skill_names))
  end

  defp enemy?(%Group{} = group, {target_type, target_id}) do
    with {:ok, {_module, caster, _pid}} <-
           UnitRegistry.get_unit(group.caster_type, group.caster_id),
         {:ok, {_module, target, _pid}} <- UnitRegistry.get_unit(target_type, target_id) do
      field_target?(group, caster, target)
    else
      _unavailable -> false
    end
  end

  defp field_target?(%Group{caster_type: :player} = group, caster, target),
    do: Targeting.validate_field_target(group, caster, target) == :ok

  defp field_target?(%Group{}, caster, target),
    do: Targeting.validate_enemy(caster, target) == :ok
end
