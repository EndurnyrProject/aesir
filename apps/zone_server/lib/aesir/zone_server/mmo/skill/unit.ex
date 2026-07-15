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
  alias Aesir.ZoneServer.Unit.Broadcast
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
  @spec place(PlayerState.t(), atom(), non_neg_integer(), {integer(), integer()}) ::
          {:ok, Group.t()} | {:error, term()}
  def place(%PlayerState{} = caster_state, skill_name, level, {x, y}) do
    with {:ok, module} <- module_for(skill_name),
         {:ok, definition} <- skill_definition(skill_name) do
      group = build_group(caster_state, definition.id, skill_name, level, {x, y})
      {:ok, placement} = module.on_place(group)
      register_placement(group, caster_state.map_name, placement)
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
  def snapshot(map_name), do: Manager.snapshot(map_name, ServerTick.now())

  @doc "Returns visible groups whose footprints intersect a square range."
  @spec in_range(String.t(), integer(), integer(), non_neg_integer()) :: [Group.t()]
  def in_range(map_name, x, y, range), do: Manager.in_range(map_name, x, y, range)

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

  defp build_group(%PlayerState{} = caster_state, skill_id, skill_name, level, {x, y}) do
    %Group{
      group_id: System.unique_integer([:monotonic, :positive]),
      skill_id: skill_id,
      skill_name: skill_name,
      level: level,
      caster_id: caster_state.character_id,
      caster_type: :player,
      map_name: caster_state.map_name,
      center: {x, y}
    }
  end

  defp accepted_cells(map_name, cells) do
    case MapCache.get(map_name) do
      {:ok, %{xs: width, ys: height}} ->
        Enum.filter(cells, fn {x, y} -> x >= 0 and x < width and y >= 0 and y < height end)

      {:error, :not_found} ->
        []
    end
  end

  defp register_placement(group, map_name, placement) do
    case accepted_cells(map_name, placement.cells) do
      [] ->
        {:error, :no_walkable_cells}

      cells ->
        now = System.monotonic_time(:millisecond)
        initial_delay = Map.get(placement, :initial_delay, placement.interval)

        group = %{
          group
          | cells: cells,
            created_at: now,
            visible?: true,
            state: placement.state,
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
