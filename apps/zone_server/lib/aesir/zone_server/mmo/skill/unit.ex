defmodule Aesir.ZoneServer.Mmo.Skill.Unit do
  @moduledoc """
  Facade for placing ground skill-units (design §"Behavior dispatch").

  A ground skill's auto-derived `cast/4` calls `place/4` instead of dealing
  damage directly: it resolves the skill's `Skill.Ground` module via
  `Skill.Catalog`, runs `on_place` to compute the footprint and timing, inserts
  the resulting `Group` into `Skill.Unit.Storage` (where the central
  `TickManager` picks it up), and broadcasts the ground-cast animation to nearby
  players.
  """

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.GroundSkill
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
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
          {:ok, Group.t()} | {:error, :no_skill_unit_behaviour | :unknown_skill}
  def place(%PlayerState{} = caster_state, skill_name, level, {x, y}) do
    with {:ok, module} <- module_for(skill_name),
         {:ok, definition} <- skill_definition(skill_name) do
      group = build_group(caster_state, definition.id, skill_name, level, {x, y})
      {:ok, placement} = module.on_place(group)

      now = System.monotonic_time(:millisecond)

      group = %{
        group
        | cells: placement.cells,
          state: placement.state,
          interval: placement.interval,
          next_tick_at: now + placement.interval,
          expires_at: now + placement.duration
      }

      :ok = Storage.insert(group)
      broadcast_groundskill(group)

      {:ok, group}
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
  def update_state(group_id, state) do
    case Storage.get(group_id) do
      nil ->
        :ok

      %Group{state: existing} = group ->
        Storage.update(%{group | state: Map.merge(existing, state)})
    end
  end

  @doc """
  Destroys a ground skill-unit group by `group_id` (rAthena `skill_delunitgroup`).

  Runs the skill's `on_expire/1` cleanup hook and deletes the group from storage.
  A no-op when the group is already gone. Used when a unit dies ahead of its
  duration, e.g. a Safety Wall whose hit/shield budget is exhausted.
  """
  @spec destroy(non_neg_integer()) :: :ok
  def destroy(group_id) do
    case Storage.get(group_id) do
      nil ->
        :ok

      %Group{skill_name: skill_name} = group ->
        with {:ok, module} <- module_for(skill_name) do
          module.on_expire(group)
        end

        Storage.delete(group_id)
    end
  end

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
