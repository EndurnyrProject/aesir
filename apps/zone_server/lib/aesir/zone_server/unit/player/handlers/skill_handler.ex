defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler do
  @moduledoc """
  Session-side handler for skill casts. Runs the interpreter, then on success
  updates the registry, persists SP, syncs SP to the client, and broadcasts the
  skill-use visual to nearby players.
  """
  require Logger

  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Packets.ZcSkillPostdelay
  alias Aesir.ZoneServer.Packets.ZcUseSkill
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @skill_view_range 14

  @spec handle_use_skill(map(), integer(), pos_integer(), integer()) :: {:noreply, map()}
  def handle_use_skill(
        %{game_state: game_state, connection_pid: connection_pid} = state,
        skill_id,
        level,
        target_id
      ) do
    target = resolve_target(game_state, target_id)

    case Interpreter.cast(game_state, skill_id, level, target) do
      {:ok, new_game_state} ->
        new_game_state = commit_cast(state, new_game_state, skill_id, level)
        broadcast_skill_use(new_game_state, skill_id, level, target_id)
        {:noreply, %{state | game_state: new_game_state}}

      {:error, reason} ->
        log_cast_failure(skill_id, game_state.character_id, reason)
        {:noreply, state}
    end
  end

  @spec handle_use_skill_ground(map(), integer(), pos_integer(), integer(), integer()) ::
          {:noreply, map()}
  def handle_use_skill_ground(
        %{game_state: game_state} = state,
        skill_id,
        level,
        x,
        y
      ) do
    case Interpreter.cast(game_state, skill_id, level, {:ground, x, y}) do
      {:ok, new_game_state} ->
        new_game_state = commit_cast(state, new_game_state, skill_id, level)
        {:noreply, %{state | game_state: new_game_state}}

      {:error, reason} ->
        log_cast_failure(skill_id, game_state.character_id, reason)
        {:noreply, state}
    end
  end

  # Shared success path: recalc stats, update registry, persist SP, sync to client,
  # and emit the cooldown sweep. The ground variant skips the ZcUseSkill broadcast -
  # placement emits its own ZcNotifyGroundskill visual.
  defp commit_cast(%{connection_pid: connection_pid}, new_game_state, skill_id, level) do
    updated_stats = Stats.calculate_stats(new_game_state.stats, new_game_state.character_id)
    new_game_state = %{new_game_state | stats: updated_stats}

    UnitRegistry.update_unit_state(:player, new_game_state.character_id, new_game_state)

    CharacterPersistence.update_character(
      new_game_state.character_id,
      %{sp: updated_stats.current_state.sp},
      async: true
    )

    StatusSync.send_stat_updates(connection_pid, updated_stats)

    maybe_send_postdelay(connection_pid, skill_id, level)

    new_game_state
  end

  defp log_cast_failure(skill_id, character_id, reason) do
    Logger.debug("Skill #{skill_id} cast failed for #{character_id}: #{inspect(reason)}")
  end

  defp resolve_target(%{character_id: caster_id}, target_id) when target_id == caster_id,
    do: :self

  defp resolve_target(_game_state, target_id), do: {:unit, target_id}

  # Self-only cooldown feedback: the client shows the cooldown sweep on the
  # skill icon. No packet when the skill has no cooldown for this level.
  defp maybe_send_postdelay(connection_pid, skill_id, level) do
    with {:ok, definition} <- Catalog.by_id(skill_id),
         duration when duration > 0 <- Cooldown.duration(definition, level) do
      send(connection_pid, {:send_packet, %ZcSkillPostdelay{skill_id: skill_id, tick: duration}})
    else
      _ -> :ok
    end
  end

  # Damage skills broadcast their own ZC_NOTIFY_SKILL from the combat layer, so
  # the no-damage support visual is sent only for no-damage skills.
  defp broadcast_skill_use(game_state, skill_id, level, target_id) do
    case Catalog.by_id(skill_id) do
      {:ok, %{damage_type: :damage}} ->
        :ok

      _ ->
        packet = %ZcUseSkill{
          skill_id: skill_id,
          level: level,
          dst_id: target_id,
          src_id: game_state.character_id,
          result: 1
        }

        Broadcast.to_in_range(
          game_state.map_name,
          game_state.x,
          game_state.y,
          @skill_view_range,
          packet
        )
    end
  end
end
