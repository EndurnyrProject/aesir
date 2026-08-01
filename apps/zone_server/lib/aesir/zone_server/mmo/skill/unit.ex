defmodule Aesir.ZoneServer.Mmo.Skill.Unit do
  @moduledoc """
  Facade for placing ground skill-units (design §"Behavior dispatch").

  A ground skill's auto-derived `cast/4` calls `place/4` instead of dealing
  damage directly: it resolves the skill's `Skill.Ground` module via
  `Skill.Catalog`, runs `on_place` to compute the footprint and timing, inserts
  the resulting `Group` through `Skill.Unit.Manager`, and broadcasts the
  ground-cast animation to nearby players after the state is committed.
  """

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.GroundSkill
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.View
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @doc """
  Places a ground skill-unit cast by `caster_state` at cell `{x, y}`.

  Resolves the skill's behaviour module, runs `on_place/1`, inserts the group with
  `next_tick_at = now + interval` and `expires_at = now + duration`, and broadcasts
  one `GroundSkill` (the cast animation) to players in range.

  Returns `{:error, :no_skill_unit_behaviour}` when the skill has no registered
  ground-unit behaviour, or `{:error, :unknown_skill}` when the skill name is not
  in the catalog.
  """
  @spec place(PlayerState.t() | MobState.t(), atom(), non_neg_integer(), {integer(), integer()}) ::
          {:ok, Group.t()} | {:error, term()}
  def place(caster_state, skill_name, level, cell),
    do: place(caster_state, skill_name, level, cell, origin: :direct)

  @doc """
  Places a ground skill with atomic caller-provided state and cast origin.

  `:state` is merged with the skill's `on_place/1` state before registration.
  `:origin` defaults to `:direct` and records which validated entry point caused
  the placement without changing placement validation.
  """
  @spec place(
          PlayerState.t() | MobState.t(),
          atom(),
          non_neg_integer(),
          {integer(), integer()},
          keyword()
        ) :: {:ok, Group.t()} | {:error, term()}
  def place(caster_state, skill_name, level, {x, y}, opts) do
    initial_state =
      opts
      |> Keyword.get(:state, %{})
      |> Map.put(:cast_origin, Keyword.get(opts, :origin, :direct))

    with {:ok, _module} <- module_for(skill_name),
         {:ok, definition} <- skill_definition(skill_name) do
      caster_state
      |> build_group(definition.id, skill_name, level, {x, y}, initial_state)
      |> place_group({caster_state.x, caster_state.y})
    end
  end

  @doc """
  Runs a prepared group's `on_place/1` and registers the resulting placement.

  The seam `place/4` shares with casters that have no `PlayerState` — ground
  mob skills (e.g. `NpcGroundattack`, `NpcEarthquake`) build their own `Group`
  (`caster_type: :mob`) and get the identical footprint, path check,
  registration and cast broadcast.
  `origin` is the caster's cell: it is stamped onto the group before `on_place/1`
  runs (so directional skills read it without calling back into the caster's
  process) and drives the placement's optional path check.
  """
  @spec place_group(Group.t(), {integer(), integer()}) :: {:ok, Group.t()} | {:error, term()}
  def place_group(%Group{} = group, origin) do
    group = %{group | origin: origin}

    with {:ok, module} <- module_for(group.skill_name) do
      {:ok, placement} = module.on_place(group)
      register_placement(group, origin, placement)
    end
  end

  @doc """
  Fetches a stored ground skill-unit group by `group_id`.

  Returns `:error` when the group is no longer alive (expired or destroyed).
  """
  @spec fetch(non_neg_integer()) :: {:ok, Group.t()} | :error
  def fetch(group_id) do
    case Storage.get(group_id) do
      nil -> :error
      %Group{} = group -> {:ok, group}
    end
  end

  @doc """
  Merges `state` into a stored group's per-skill `state` map.

  A no-op when the group is already gone, so a caller racing a teardown never
  resurrects it.
  """
  @spec update_state(non_neg_integer(), map()) :: :ok
  def update_state(group_id, state), do: Manager.update_state(group_id, state)

  @doc "Atomically spends one qualifying hit from a Safety Wall's shared budget."
  @spec absorb_safetywall_hit(non_neg_integer(), pos_integer()) ::
          Manager.safetywall_absorb_result()
  def absorb_safetywall_hit(group_id, damage),
    do: Manager.absorb_safetywall_hit(group_id, damage)

  @doc """
  Destroys a ground skill-unit group by `group_id` (rAthena `skill_delunitgroup`).

  Runs the skill's `on_expire/1` cleanup hook and deletes the group from storage.
  A no-op when the group is already gone. Used when a unit dies ahead of its
  duration, e.g. a Safety Wall whose hit/shield budget is exhausted.
  """
  @spec destroy(non_neg_integer()) :: :ok
  def destroy(group_id), do: Manager.destroy(group_id)

  @doc "Builds the complete visible skill-unit snapshot for a map."
  @spec snapshot(String.t()) :: Aesir.Net.SkillUnitSnapshot.t()
  def snapshot(map_name) do
    groups =
      Storage.all()
      |> Enum.filter(&(&1.map_name == map_name and Group.public?(&1)))
      |> Enum.map(&{&1, Storage.get_cells_by_group(&1.group_id)})

    View.snapshot(groups, ServerTick.now())
  end

  @doc "Returns visible groups whose footprints intersect a square range."
  @spec in_range(String.t(), integer(), integer(), non_neg_integer()) :: [Group.t()]
  def in_range(map_name, x, y, range),
    do: Storage.get_visible_groups_in_range(map_name, x, y, range)

  defp module_for(skill_name) do
    case Catalog.ground_module_for(skill_name) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :no_skill_unit_behaviour}
    end
  end

  defp skill_definition(skill_name) do
    case Catalog.by_name(skill_name) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, :unknown_skill}
    end
  end

  defp build_group(caster_state, skill_id, skill_name, level, {x, y}, initial_state) do
    {caster_id, caster_type} = caster_identity(caster_state)

    %Group{
      group_id: System.unique_integer([:monotonic, :positive]),
      skill_id: skill_id,
      skill_name: skill_name,
      level: level,
      caster_id: caster_id,
      caster_type: caster_type,
      map_name: caster_state.map_name,
      center: {x, y},
      state: initial_state
    }
  end

  defp caster_identity(%PlayerState{character_id: character_id}), do: {character_id, :player}
  defp caster_identity(%MobState{instance_id: instance_id}), do: {instance_id, :mob}

  defp accepted_cells(map_name, cells, origin, path_check?) do
    case MapCache.get(map_name) do
      {:ok, %{xs: width, ys: height}} ->
        Enum.filter(cells, fn {x, y} = cell ->
          x >= 0 and x < width and y >= 0 and y < height and
            (not path_check? or reachable?(map_name, origin, cell))
        end)

      {:error, :not_found} ->
        []
    end
  end

  defp register_placement(%Group{map_name: map_name} = group, origin, placement) do
    case accepted_cells(map_name, placement.cells, origin, Map.get(placement, :path_check, false)) do
      [] ->
        {:error, :no_walkable_cells}

      cells ->
        now = System.monotonic_time(:millisecond)
        initial_delay = Map.get(placement, :initial_delay, placement.interval)
        state = Map.merge(group.state, placement_state(placement))

        group = %{
          group
          | cells: cells,
            created_at: now,
            visibility: Map.get(placement, :visibility, :public),
            state: state,
            interval: placement.interval,
            lifecycle_policy: Map.get(placement, :lifecycle_policy, group.lifecycle_policy),
            next_tick_at: now + initial_delay,
            expires_at: now + placement.duration
        }

        case Manager.register(group) do
          :ok ->
            broadcast_groundskill(group)
            {:ok, group}

          {:error, _reason} = error ->
            error
        end
    end
  end

  defp reachable?(map_name, origin, cell) do
    with {:ok, map_data} <- MapCache.get(map_name),
         {:ok, _path} <- Pathfinding.find_path(map_data, origin, cell) do
      true
    else
      _ -> false
    end
  end

  defp placement_state(%{cell_attrs: cell_attrs, state: state}),
    do: Map.put(state, :cell_attrs, cell_attrs)

  defp placement_state(%{state: state}), do: state

  defp broadcast_groundskill(%Group{center: {x, y}} = group) do
    packet = %GroundSkill{
      skill_id: group.skill_id,
      src_id: group.caster_id,
      level: group.level,
      x: x,
      y: y,
      server_tick: ServerTick.now()
    }

    Broadcast.to_in_range(group.map_name, x, y, Config.view_range(), packet)
  end
end
