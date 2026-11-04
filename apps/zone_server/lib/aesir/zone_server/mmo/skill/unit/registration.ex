defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Registration do
  @moduledoc """
  The placement rules applied when a prepared group is registered: the
  serial reiteration check, per-caster exclusive families, Land Protector,
  skill metadata and the handler's own scheduling, in that order, before the
  group is stored.

  Every function runs inside `Skill.Unit.Manager`.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.GroupLifecycle
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Handler
  alias Aesir.ZoneServer.Mmo.Skill.Unit.PlacementCheck
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  @venom_dust_skill_id 140

  @type rng :: (pos_integer() -> non_neg_integer())

  @doc "Applies every placement rule to a group and stores it."
  @spec register(Group.t(), integer(), rng()) :: {:ok, Group.t()} | {:error, term()}
  def register(%Group{} = group, now, rng) do
    with :ok <- ensure_not_reiterated(group),
         {:ok, group} <- apply_exclusive_family(group, now),
         {:ok, group} <- add_venom_dust_metadata(group),
         {:ok, group} <- apply_land_protector(group),
         {:ok, group} <- schedule(group, rng) do
      GroupLifecycle.register(group)
    end
  end

  # The cast already checked its placement, but another caster may have placed
  # a reiterated unit since; registrations run one at a time here, so the
  # second of two racing placements is refused as the source's serial cast end
  # would refuse it.
  defp ensure_not_reiterated(%Group{} = group) do
    with {:ok, definition} <- Catalog.by_id(group.skill_id),
         true <-
           PlacementCheck.reiteration_blocked?(
             definition,
             group.caster_type,
             group.map_name,
             group.center
           ) do
      {:error, :unit_placement_refused}
    else
      _placeable -> :ok
    end
  end

  # Per-caster family exclusivity: placing a member of an exclusive family
  # clears the caster's existing member first, and only the caster's - other
  # casters' fields are untouched. Placing any member over a replaced group
  # that opted into inherit_family_duration carries that group's *remaining*
  # duration into the new one, so a recast (or a Land Protector placed over an
  # element field) never refreshes it.
  defp apply_exclusive_family(%Group{lifecycle_policy: %{exclusive_family: nil}} = group, _now),
    do: {:ok, group}

  defp apply_exclusive_family(%Group{} = group, now) do
    case family_groups(group) do
      [] ->
        {:ok, group}

      [replaced | _] = groups ->
        Enum.each(
          groups,
          &GroupLifecycle.cleanup_with_reason(&1, :SKILL_UNIT_DESPAWN_REASON_CANCELED)
        )

        {:ok, inherit_family_duration(group, replaced, now)}
    end
  end

  defp family_groups(%Group{lifecycle_policy: %{exclusive_family: family}} = group) do
    group.caster_type
    |> Storage.get_groups_by_caster(group.caster_id)
    |> Enum.filter(
      &(&1.group_id != group.group_id and &1.lifecycle_policy.exclusive_family == family)
    )
    |> Enum.sort_by(&{&1.created_at, &1.group_id})
  end

  # Keyed on the *replaced* group's policy only: whatever replaces an element
  # field inherits its remaining duration, including Land Protector. The trio
  # opt in (a recast never refreshes); Land Protector does not, so placing an
  # element field over an existing Land Protector still gets a fresh duration.
  defp inherit_family_duration(
         %Group{} = group,
         %Group{lifecycle_policy: %{inherit_family_duration: true}, expires_at: expires_at},
         now
       )
       when expires_at > now,
       do: %{group | expires_at: expires_at}

  defp inherit_family_duration(%Group{} = group, %Group{}, _now), do: group

  defp add_venom_dust_metadata(%Group{skill_id: @venom_dust_skill_id} = group),
    do: {:ok, %{group | state: Map.put(group.state, :removed_by_fire_rain, true)}}

  defp add_venom_dust_metadata(%Group{} = group), do: {:ok, group}

  # Land Protector's central placement rules: a Land Protector group destroys
  # overlapping foreign cells per cell (mutually with an existing Land
  # Protector), and any other placement drops candidate cells that fall on a
  # Land Protector. A RangedSingleUnit field goes whole only when its centre
  # cell is covered and otherwise keeps its covered cells beside the new Land
  # Protector cell. A group reduced to zero cells fails registration with
  # `:land_protector`.
  defp apply_land_protector(%Group{} = group) do
    cond do
      Group.land_protector?(group) -> sweep_protected_overlap(group)
      Group.ignores_land_protector?(group) -> {:ok, group}
      true -> drop_protected_cells(group)
    end
  end

  defp drop_protected_cells(%Group{cells: []} = group), do: {:ok, group}

  defp drop_protected_cells(%Group{} = group) do
    case Enum.reject(group.cells, fn {x, y} -> Storage.land_protected?(group.map_name, x, y) end) do
      [] -> {:error, :land_protector}
      cells -> {:ok, %{group | cells: cells}}
    end
  end

  defp sweep_protected_overlap(%Group{} = group) do
    {kept, removals} =
      Enum.reduce(group.cells, {[], %{}}, fn {x, y} = cell, {kept, removals} ->
        overlapping =
          group.map_name
          |> Storage.get_groups_at_cell(x, y)
          |> Enum.reject(&Group.ignores_land_protector?/1)

        removals = Enum.reduce(overlapping, removals, &mark_removal(&2, &1, cell))

        if Enum.any?(overlapping, &Group.land_protector?/1),
          do: {kept, removals},
          else: {[cell | kept], removals}
      end)

    Enum.each(removals, fn {victim_id, cells} ->
      if victim = Storage.get(victim_id),
        do: GroupLifecycle.remove_cells(victim, MapSet.new(cells))
    end)

    case kept do
      [] -> {:error, :land_protector}
      kept -> {:ok, %{group | cells: Enum.reverse(kept)}}
    end
  end

  defp mark_removal(removals, %Group{} = victim, cell) do
    cond do
      not GroupLifecycle.ranged_single_unit?(victim) ->
        Map.update(removals, victim.group_id, [cell], &[cell | &1])

      GroupLifecycle.centre_unit_in?(victim, MapSet.new([cell])) ->
        Map.put(removals, victim.group_id, victim.cells)

      true ->
        removals
    end
  end

  defp schedule(%Group{} = group, rng) do
    with {:ok, module} <- Handler.for_group(group),
         true <- function_exported?(module, :schedule, 2) do
      case Handler.invoke(module, :schedule, [group, rng]) do
        {:ok, {:ok, %Group{group_id: group_id} = scheduled}} when group_id == group.group_id ->
          {:ok, scheduled}

        {:ok, {:ok, %Group{group_id: group_id}}} ->
          {:error, {:schedule_foreign_group_id, group_id}}

        {:ok, result} ->
          {:error, {:invalid_schedule_return, result}}

        {:error, reason} ->
          {:error, {:schedule_failed, reason}}
      end
    else
      :error -> {:ok, group}
      false -> {:ok, group}
    end
  end
end
