defmodule Aesir.ZoneServer.Mmo.SkillUnit do
  @moduledoc """
  Facade for placing ground skill-units (design §"Behavior dispatch").

  A ground skill's `cast/4` calls `place/4` instead of dealing damage directly:
  it resolves the skill's `SkillUnit.Behaviour`, runs `on_place` to compute the
  footprint and timing, inserts the resulting `Group` into `SkillUnit.Storage`
  (where the central `TickManager` picks it up), and broadcasts the ground-cast
  animation to nearby players.
  """

  alias Aesir.ZoneServer.Mmo.SkillUnit.Behaviors
  alias Aesir.ZoneServer.Mmo.SkillUnit.Group
  alias Aesir.ZoneServer.Mmo.SkillUnit.Storage
  alias Aesir.ZoneServer.Packets.ZcNotifyGroundskill
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # Matches the skill-cast view range used by the active-skill handler.
  @view_range 14

  @doc """
  Places a ground skill-unit cast by `caster_state` at cell `{x, y}`.

  Resolves the skill's behaviour module, runs `on_place/1`, inserts the group with
  `next_tick_at = now + interval` and `expires_at = now + duration`, and broadcasts
  one `ZcNotifyGroundskill` (the cast animation) to players in range.

  Returns `{:error, :no_skill_unit_behaviour}` when the skill has no registered
  ground-unit behaviour.
  """
  @spec place(PlayerState.t(), atom(), non_neg_integer(), {integer(), integer()}) ::
          {:ok, Group.t()} | {:error, :no_skill_unit_behaviour}
  def place(%PlayerState{} = caster_state, skill_name, level, {x, y}) do
    with {:ok, module} <- module_for(skill_name) do
      group = build_group(caster_state, skill_name, level, {x, y})
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

  defp module_for(skill_name) do
    case Behaviors.module_for(skill_name) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :no_skill_unit_behaviour}
    end
  end

  defp build_group(%PlayerState{} = caster_state, skill_name, level, {x, y}) do
    %Group{
      group_id: System.unique_integer([:monotonic, :positive]),
      skill_name: skill_name,
      level: level,
      caster_id: caster_state.character_id,
      caster_type: :player,
      map_name: caster_state.map_name,
      center: {x, y}
    }
  end

  defp broadcast_groundskill(%Group{center: {x, y}} = group) do
    packet = %ZcNotifyGroundskill{
      skill_id: group.skill_id,
      src_id: group.caster_id,
      level: group.level,
      x: x,
      y: y
    }

    Broadcast.to_in_range(group.map_name, x, y, @view_range, packet)
  end
end
