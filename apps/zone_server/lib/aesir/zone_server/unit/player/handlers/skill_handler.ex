defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler do
  @moduledoc """
  Session-side handler for skill casts. Runs the interpreter's two-phase
  lifecycle: instant casts commit immediately, timed casts enter `:casting`,
  show a cast bar, and resolve on a `{:cast_complete, token}` timer. On a
  successful commit it updates the registry, persists HP/SP, syncs them to the
  client, and broadcasts the skill-use visual to nearby players.
  """
  require Logger

  alias Aesir.Net.CastCancel
  alias Aesir.Net.SkillCasting
  alias Aesir.Net.SkillCooldown
  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @spec handle_use_skill(map(), integer(), pos_integer(), integer()) :: {:noreply, map()}
  def handle_use_skill(%{game_state: game_state} = state, skill_id, level, target_id) do
    if StatusInterpreter.can_use_skill?(:player, game_state.character_id) do
      target = resolve_target(game_state, target_id)
      drive_cast(state, skill_id, level, target)
    else
      broadcast_cast_cancel(game_state)
      {:noreply, state}
    end
  end

  @spec handle_use_skill_ground(map(), integer(), pos_integer(), integer(), integer()) ::
          {:noreply, map()}
  def handle_use_skill_ground(%{game_state: game_state} = state, skill_id, level, x, y) do
    if StatusInterpreter.can_use_skill?(:player, game_state.character_id) do
      drive_cast(state, skill_id, level, {:ground, x, y})
    else
      broadcast_cast_cancel(game_state)
      {:noreply, state}
    end
  end

  @doc """
  Resolves a fired cast timer. Runs the behavior to completion only when the
  player is still casting under the same token; stale tokens are dropped.
  """
  @spec handle_cast_complete(map(), reference()) :: {:noreply, map()}
  def handle_cast_complete(
        %{game_state: %{action_state: :casting, state_context: %{token: token} = ctx}} = state,
        token
      ) do
    game_state = state.game_state

    if StatusInterpreter.can_use_skill?(:player, game_state.character_id) do
      complete_cast(state, game_state, ctx)
    else
      broadcast_cast_cancel(game_state)
      {:noreply, %{state | game_state: to_idle(game_state)}}
    end
  end

  def handle_cast_complete(state, _token), do: {:noreply, state}

  defp complete_cast(state, game_state, ctx) do
    case Interpreter.complete_cast(game_state, ctx.skill_id, ctx.skill_level, ctx.target) do
      {:ok, new_game_state} ->
        new_game_state = commit_cast(state, new_game_state, ctx.skill_id, ctx.skill_level)
        broadcast_skill_use(new_game_state, ctx.skill_id, ctx.skill_level, ctx.target)
        {:noreply, %{state | game_state: to_idle(new_game_state)}}

      {:error, reason} ->
        log_cast_failure(ctx.skill_id, game_state.character_id, reason)
        {:noreply, %{state | game_state: to_idle(game_state)}}
    end
  end

  @doc """
  Phase-aware damage interruption. A cast is immune during the fixed phase
  (`now < fixed_until`) and cancellable once it reaches the variable phase, as
  long as it is flagged interruptible. Anything else passes through unchanged.
  """
  @spec interrupt_cast_on_damage(map()) :: map()
  def interrupt_cast_on_damage(
        %{game_state: %{action_state: :casting, state_context: ctx}} = state
      ) do
    now = System.monotonic_time(:millisecond)

    if now >= ctx.fixed_until and ctx.interruptible do
      cancel_cast(state, :damage)
    else
      state
    end
  end

  def interrupt_cast_on_damage(state), do: state

  @doc """
  Forced cancel, phase-agnostic (used by movement). Cancels any in-flight cast
  and returns the player to idle; a non-casting state is returned unchanged.
  """
  @spec cancel_cast(map(), atom()) :: map()
  def cancel_cast(
        %{game_state: %{action_state: :casting, state_context: ctx} = game_state} = state,
        _reason
      ) do
    Process.cancel_timer(ctx.timer_ref)
    broadcast_cast_cancel(game_state)

    case PlayerState.transition_to(game_state, :idle) do
      {:ok, idle_game_state} -> %{state | game_state: idle_game_state}
      {:error, _reason} -> %{state | game_state: game_state}
    end
  end

  def cancel_cast(state, _reason), do: state

  defp broadcast_cast_cancel(game_state) do
    packet = %CastCancel{gid: game_state.character_id}

    Broadcast.to_player(game_state.character_id, packet)

    Broadcast.to_in_range(
      game_state.map_name,
      game_state.x,
      game_state.y,
      Config.view_range(),
      packet,
      exclude_id: game_state.character_id
    )
  end

  # A cast may only begin from idle, so an instant skill can't slip past the cast
  # lock while a timed cast is in flight, nor stack on any other busy action.
  # Once idle is guaranteed, branch on the interpreter's two-phase result: instant
  # casts commit now, timed casts schedule a cast-complete timer and a cast bar.
  defp drive_cast(%{game_state: game_state} = state, skill_id, level, target) do
    case ensure_idle_for_cast(state) do
      {:ok, ready_state} ->
        dispatch_cast(ready_state, skill_id, level, target)

      :busy ->
        Logger.debug(
          "Skill #{skill_id} cast skipped for #{game_state.character_id}: busy in #{game_state.action_state}"
        )

        {:noreply, state}
    end
  end

  defp dispatch_cast(%{game_state: game_state} = state, skill_id, level, target) do
    case Interpreter.begin_cast(game_state, skill_id, level, target) do
      {:instant, new_game_state} ->
        new_game_state = commit_cast(state, new_game_state, skill_id, level)
        broadcast_skill_use(new_game_state, skill_id, level, target)
        {:noreply, %{state | game_state: new_game_state}}

      {:casting, new_game_state, info} ->
        schedule_cast(%{state | game_state: new_game_state}, info)

      {:error, reason} ->
        log_cast_failure(skill_id, game_state.character_id, reason)
        {:noreply, state}
    end
  end

  # A cast may only begin from idle. A moving player is stopped first (using a
  # skill ends movement); any other busy state (casting, attacking, sitting,
  # trading, vending) aborts so a player can't act while a cast is in flight or
  # stack a second action on top of a busy one.
  defp ensure_idle_for_cast(%{game_state: %{action_state: :idle}} = state), do: {:ok, state}

  defp ensure_idle_for_cast(%{game_state: %{action_state: moving}} = state)
       when moving in [:moving, :combat_moving] do
    {:noreply, stopped_state} = MovementHandler.handle_force_stop_movement(state)

    case PlayerState.transition_to(stopped_state.game_state, :idle) do
      {:ok, idle_game_state} -> {:ok, %{stopped_state | game_state: idle_game_state}}
      {:error, _reason} -> :busy
    end
  end

  defp ensure_idle_for_cast(_state), do: :busy

  defp schedule_cast(%{game_state: game_state} = state, info) do
    now = System.monotonic_time(:millisecond)
    token = make_ref()
    timer_ref = Process.send_after(self(), {:cast_complete, token}, info.total)

    context = %{
      skill_id: info.skill_id,
      skill_level: info.level,
      target: info.target,
      element: info.element,
      started_at: now,
      fixed_until: now + info.fixed,
      total_until: now + info.total,
      timer_ref: timer_ref,
      token: token,
      interruptible: true
    }

    case PlayerState.transition_to(game_state, :casting, context) do
      {:ok, casting_state} ->
        broadcast_cast_bar(casting_state, info)
        {:noreply, %{state | game_state: casting_state}}

      {:error, reason} ->
        Process.cancel_timer(timer_ref)
        log_cast_failure(info.skill_id, game_state.character_id, reason)
        {:noreply, state}
    end
  end

  defp broadcast_cast_bar(game_state, info) do
    {dst_id, x, y} = cast_bar_target(game_state, info.target)

    packet = %SkillCasting{
      src_id: game_state.character_id,
      target_id: dst_id,
      x: x,
      y: y,
      skill_id: info.skill_id,
      property: ElementModifiers.id(info.element),
      cast_time: info.total
    }

    Broadcast.to_player(game_state.character_id, packet)

    Broadcast.to_in_range(
      game_state.map_name,
      game_state.x,
      game_state.y,
      Config.view_range(),
      packet,
      exclude_id: game_state.character_id
    )
  end

  defp cast_bar_target(%{character_id: caster_id}, :self), do: {caster_id, 0, 0}
  defp cast_bar_target(_game_state, {:unit, id}), do: {id, 0, 0}
  defp cast_bar_target(_game_state, {:ground, x, y}), do: {0, x, y}

  defp to_idle(game_state) do
    case PlayerState.transition_to(game_state, :idle) do
      {:ok, idle_game_state} -> idle_game_state
      {:error, _reason} -> game_state
    end
  end

  # Shared success path: persist catalyst consumption, recalc stats, update
  # registry, persist HP/SP, sync to client, and emit the cooldown sweep.
  defp commit_cast(%{connection_pid: connection_pid}, new_game_state, skill_id, level) do
    new_game_state = persist_catalysts(new_game_state)

    updated_stats = Stats.calculate_stats(new_game_state.stats, new_game_state.character_id)
    new_game_state = %{new_game_state | stats: updated_stats}

    UnitRegistry.update_unit_state(:player, new_game_state.character_id, new_game_state)

    CharacterPersistence.update_character(
      new_game_state.character_id,
      %{hp: updated_stats.current_state.hp, sp: updated_stats.current_state.sp},
      async: true
    )

    StatusSync.send_stat_updates(connection_pid, updated_stats)

    maybe_send_postdelay(connection_pid, skill_id, level)

    new_game_state
  end

  # Writes through each catalyst-consumption delta the interpreter staged, then
  # clears the staging field. Each delta is persisted against the snapshot it was
  # computed from; the persisted rows (with real DB ids) are reflected back onto
  # the interpreter's already-final inventory for the indices that survive.
  defp persist_catalysts(%{pending_inventory_persist: []} = game_state), do: game_state

  defp persist_catalysts(%{pending_inventory_persist: deltas} = game_state) do
    char_id = game_state.character_id
    final = game_state.inventory

    inventory =
      Enum.reduce(deltas, final, fn {old_inv, new_inv, change}, acc ->
        case InventoryOps.apply_change(char_id, old_inv, new_inv, change) do
          {:ok, persisted} ->
            Map.merge(acc, Map.take(persisted, Map.keys(acc)))

          {:error, reason} ->
            Logger.warning("Catalyst persist failed for #{char_id}: #{inspect(reason)}")
            acc
        end
      end)

    %{game_state | inventory: inventory, pending_inventory_persist: []}
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
      MessageRouter.send_to(connection_pid, %SkillCooldown{skill_id: skill_id, tick: duration})
    else
      _ -> :ok
    end
  end

  # Damage skills broadcast their own ZC_NOTIFY_SKILL from the combat layer, so
  # the no-damage support visual is sent only for no-damage skills. Ground casts
  # emit their own ZC_NOTIFY_GROUNDSKILL visual, so they skip this entirely.
  defp broadcast_skill_use(_game_state, _skill_id, _level, {:ground, _x, _y}), do: :ok

  defp broadcast_skill_use(game_state, skill_id, level, target) do
    case Catalog.by_id(skill_id) do
      {:ok, %{damage_type: :damage}} ->
        :ok

      _ ->
        packet = %SkillEffect{
          skill_id: skill_id,
          level: level,
          target_id: skill_use_target_id(game_state, target),
          src_id: game_state.character_id,
          result: 1
        }

        Broadcast.to_in_range(
          game_state.map_name,
          game_state.x,
          game_state.y,
          Config.view_range(),
          packet
        )
    end
  end

  defp skill_use_target_id(%{character_id: caster_id}, :self), do: caster_id
  defp skill_use_target_id(_game_state, {:unit, id}), do: id
end
