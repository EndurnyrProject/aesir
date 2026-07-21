defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler do
  @moduledoc """
  Session-side handler for skill casts. Runs the interpreter's two-phase
  lifecycle: instant casts commit immediately, timed casts enter `:casting`,
  show a cast bar, and resolve on a `{:skill, {:cast_complete, token}}` timer.
  On a successful commit it updates the registry, persists HP/SP, syncs them
  to the client, and broadcasts the skill-use visual to nearby players.
  """
  require Logger

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.CastCancel
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillCasting
  alias Aesir.Net.SkillCooldown
  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryStaging
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SpiritExchangeHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SpiritSphereHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.SpatialIndex

  # SA_CASTCANCEL cancels the caster's own in-flight cast, so it is the one skill
  # that must run while the player is busy in :casting. It is intercepted ahead of
  # `drive_cast/4` (and therefore ahead of `ensure_idle_for_cast/1`, which would
  # reject it) and never takes the ordinary cast path.
  @cast_cancel_id 275
  @combo_followup_ids [272]

  @spec handle_use_skill(SessionState.t(), integer(), pos_integer(), integer()) ::
          {:noreply, SessionState.t()}
  def handle_use_skill(state, skill_id, level, target_id) do
    state = maybe_cancel_combo(state, skill_id)
    game_state = state.game_state

    if StatusInterpreter.can_use_skill?(:player, game_state.character_id, skill_id) do
      dispatch_use_skill(state, skill_id, level, target_id)
    else
      broadcast_cast_cancel(game_state)
      {:noreply, state}
    end
  end

  defp dispatch_use_skill(state, @cast_cancel_id, level, _target_id),
    do: cast_cancel(state, level)

  defp dispatch_use_skill(%{game_state: game_state} = state, skill_id, level, target_id) do
    drive_cast(state, skill_id, level, resolve_target(game_state, target_id))
  end

  # Mirrors rAthena's ordering (`skills/mage/castcancel.cpp`): the requirement is
  # consumed first, then the cast is aborted, then the penalty is zapped. Running
  # `begin_cast/4` up front validates Cast Cancel (learned, cooldown, its own 2 SP)
  # and charges it against a state that still carries the descriptor, so a Cast
  # Cancel the player cannot afford aborts nothing. With no cast in flight,
  # `SaCastcancel.validate/4` rejects `:not_casting` here and charges nothing.
  #
  # `begin_cast/4` only reads the cast descriptor, so it is safe to run before the
  # abort; the cancel then invalidates the token before the zap is applied, and a
  # single `commit_cast/4` publishes both SP deltas at once.
  defp cast_cancel(%{game_state: game_state} = state, level) do
    case Interpreter.begin_cast(game_state, @cast_cancel_id, level, :self) do
      {:instant, charged_game_state} ->
        penalty = cast_cancel_penalty(game_state.casting, level)

        cancelled_state = cancel_cast(%{state | game_state: charged_game_state}, :castcancel)
        zapped_game_state = zap_sp(cancelled_state.game_state, penalty)

        new_state = commit_cast(cancelled_state, zapped_game_state, @cast_cancel_id, level)
        broadcast_skill_use(new_state.game_state, @cast_cancel_id, level, :self)
        {:noreply, new_state}

      {:error, reason} ->
        report_cast_failure(@cast_cancel_id, game_state.character_id, reason)
        {:noreply, state}
    end
  end

  # `sp_cost(cancelled_skill, cancelled_level) * (90 - 20*(lv-1)) / 100`, the raw
  # catalog cost (rAthena's `skill_get_sp`, before any `sp_cost_rate` modifier).
  # Higher Cast Cancel levels pay less: 90% down to 10% at level 5. A skill in
  # flight is by construction a castable catalog skill, so a lookup miss is a
  # broken invariant and crashes rather than silently cancelling for free.
  defp cast_cancel_penalty(%{skill_id: skill_id, skill_level: skill_level}, level) do
    {:ok, definition} = Catalog.by_id(skill_id)
    cost = Enum.at(definition.sp_cost, skill_level - 1)
    max(div(cost * (90 - 20 * (level - 1)), 100), 0)
  end

  defp zap_sp(game_state, 0), do: game_state

  defp zap_sp(game_state, penalty) do
    stats = game_state.stats
    current = %{stats.current_state | sp: max(stats.current_state.sp - penalty, 0)}
    %{game_state | stats: %{stats | current_state: current}}
  end

  @spec handle_use_skill_ground(SessionState.t(), integer(), pos_integer(), integer(), integer()) ::
          {:noreply, SessionState.t()}
  def handle_use_skill_ground(%{game_state: game_state} = state, skill_id, level, x, y) do
    state = %{state | game_state: PlayerState.cancel_combo(game_state)}
    game_state = state.game_state

    if StatusInterpreter.can_use_skill?(:player, game_state.character_id, skill_id) do
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
  @spec handle_cast_complete(SessionState.t(), reference()) :: {:noreply, SessionState.t()}
  def handle_cast_complete(
        %{game_state: %{casting: %{token: token} = ctx}} = state,
        token
      ) do
    game_state = state.game_state

    if StatusInterpreter.can_use_skill?(:player, game_state.character_id, ctx.skill_id) do
      complete_cast(state, game_state, ctx)
    else
      broadcast_cast_cancel(game_state)
      {:noreply, %{state | game_state: end_cast(game_state)}}
    end
  end

  def handle_cast_complete(state, _token), do: {:noreply, state}

  defp complete_cast(state, game_state, ctx) do
    case Interpreter.complete_cast(game_state, ctx.skill_id, ctx.skill_level, ctx.target) do
      {:ok, new_game_state} ->
        new_state = commit_cast(state, new_game_state, ctx.skill_id, ctx.skill_level)
        broadcast_skill_use(new_state.game_state, ctx.skill_id, ctx.skill_level, ctx.target)
        resolved_state = %{new_state | game_state: end_cast(new_state.game_state)}
        {:noreply, maybe_resume_lock(resolved_state, Map.get(ctx, :combat_target_id))}

      {:deferred, new_game_state, descriptor} ->
        {:noreply,
         resolve_deferred(
           state,
           end_cast(new_game_state),
           descriptor,
           Map.get(ctx, :combat_target_id)
         )}

      {:error, reason} ->
        report_cast_failure(ctx.skill_id, game_state.character_id, reason)
        {:noreply, %{state | game_state: end_cast(game_state)}}
    end
  end

  @doc """
  Phase-aware damage interruption. A cast is immune during the fixed phase
  (`now < fixed_until`) and cancellable once it reaches the variable phase, as
  long as it is flagged interruptible. Anything else passes through unchanged.
  """
  @spec interrupt_cast_on_damage(SessionState.t()) :: SessionState.t()
  def interrupt_cast_on_damage(
        %{game_state: %{casting: %{fixed_until: _, interruptible: _} = ctx}} = state
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
  Forced cancel, phase-agnostic (used by movement). Cancels any in-flight cast;
  a player with no cast in flight is returned unchanged.

  A standing cast returns the player to idle. A cast overlaid on a walking or
  attacking Free Caster leaves that action running — only the cast is cancelled
  (see `end_cast/1`).
  """
  @spec cancel_cast(SessionState.t(), atom()) :: SessionState.t()
  def cancel_cast(
        %{game_state: %{casting: %{timer_ref: _} = ctx} = game_state} = state,
        reason
      ) do
    Process.cancel_timer(ctx.timer_ref)
    broadcast_cast_cancel(game_state)

    cancelled_state = %{state | game_state: end_cast(game_state)}

    maybe_resume_on_cancel(cancelled_state, reason, Map.get(ctx, :combat_target_id))
  end

  def cancel_cast(state, _reason), do: state

  # A damage interrupt does not disengage: keep the target locked and resume the
  # auto-attack loop. A manual-move cancel (any other reason) is a deliberate
  # disengage, so the lock stays cleared. The pre-cast timer was already cancelled
  # by the idle transition, so no timer is double-armed.
  defp maybe_resume_on_cancel(state, :damage, target_id), do: maybe_resume_lock(state, target_id)
  defp maybe_resume_on_cancel(state, _reason, _target_id), do: state

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
    # Capture the lock before ensure_idle_for_cast/1 drops through :idle, which
    # clears combat intent. A lock present here means the player was engaged
    # (auto-attacking or approaching), so the loop is resumed after the cast.
    locked = game_state.combat_target_id

    case ensure_idle_for_cast(state) do
      {:ok, ready_state} ->
        dispatch_cast(ready_state, skill_id, level, target, locked)

      :busy ->
        report_cast_failure(skill_id, game_state.character_id, :busy)
        {:noreply, state}
    end
  end

  defp dispatch_cast(%{game_state: game_state} = state, skill_id, level, target, locked) do
    if Map.has_key?(state, :deferred_skill_result) do
      report_cast_failure(skill_id, game_state.character_id, :busy)
      {:noreply, state}
    else
      dispatch_resolved_cast(state, skill_id, level, target, locked)
    end
  end

  defp dispatch_resolved_cast(%{game_state: game_state} = state, skill_id, level, target, locked) do
    case Interpreter.begin_cast(game_state, skill_id, level, target) do
      {:instant, new_game_state} ->
        new_state = commit_cast(state, new_game_state, skill_id, level)
        # Keep the departure snapshot for this visual: commit_cast/5 may drain a
        # staged warp and move the player before the committed state returns.
        broadcast_skill_use(new_game_state, skill_id, level, target)
        {:noreply, maybe_resume_lock(new_state, locked)}

      {:deferred, new_game_state, descriptor} ->
        {:noreply, resolve_deferred(state, new_game_state, descriptor, locked)}

      {:casting, new_game_state, info} ->
        schedule_cast(%{state | game_state: new_game_state}, info, locked)

      # Out of range: walk into range instead of fizzling (mirrors attack-move).
      # The approach re-dispatches this same cast on arrival, so a moving target
      # is chased and a genuinely in-range recast just casts. The lock rides along
      # in the skill_moving context so it survives the walk-in and resumes after.
      {:error, :out_of_range} ->
        initiate_skill_movement(state, skill_id, level, target, locked)

      {:error, reason} ->
        report_cast_failure(skill_id, game_state.character_id, reason)
        {:noreply, state}
    end
  end

  @doc "Returns and clears an unsettled deferred skill result."
  @spec take_deferred_skill_result(map()) :: {map() | nil, map()}
  def take_deferred_skill_result(state) do
    pending = Map.get(state, :deferred_skill_result)
    cancel_deferred_timer(pending)
    {pending, Map.delete(state, :deferred_skill_result)}
  end

  @doc "Settles a matching Absorb Spirit Sphere reply against current caster state."
  @spec handle_spirit_absorb_result(map(), reference(), non_neg_integer(), non_neg_integer()) ::
          {:noreply, map()}
  def handle_spirit_absorb_result(
        %{deferred_skill_result: %{token: token, target_id: target_id} = pending} = state,
        token,
        target_id,
        count
      ) do
    cancel_deferred_timer(pending)
    state = Map.delete(state, :deferred_skill_result)

    case Interpreter.settle_deferred(state.game_state, pending.descriptor) do
      {:ok, charged} ->
        rewarded = restore_sp(charged, count * 7)

        new_state =
          commit_cast(
            state,
            rewarded,
            pending.descriptor.skill_id,
            pending.descriptor.level
          )

        broadcast_skill_use(
          new_state.game_state,
          pending.descriptor.skill_id,
          pending.descriptor.level,
          pending.descriptor.target
        )

        {:noreply, maybe_resume_lock(new_state, pending.combat_target_id)}

      {:error, _reason} ->
        {:noreply, maybe_resume_lock(state, pending.combat_target_id)}
    end
  end

  def handle_spirit_absorb_result(state, _token, _target_id, _count), do: {:noreply, state}

  @doc "Drops a matching deferred skill after its one-second reply window."
  @spec handle_deferred_timeout(map(), reference()) :: {:noreply, map()}
  def handle_deferred_timeout(
        %{deferred_skill_result: %{token: token} = pending} = state,
        token
      ) do
    state = Map.delete(state, :deferred_skill_result)
    {:noreply, maybe_resume_lock(state, pending.combat_target_id)}
  end

  def handle_deferred_timeout(state, _token), do: {:noreply, state}

  @doc "Cancels a pending deferred skill without charging or resuming combat."
  @spec cancel_deferred(map()) :: map()
  def cancel_deferred(state) do
    {_pending, state} = take_deferred_skill_result(state)
    state
  end

  defp resolve_deferred(
         state,
         game_state,
         %Interpreter.Deferred{effect: {:absorb_local, reward}} = descriptor,
         locked
       ) do
    case Interpreter.settle_deferred(game_state, descriptor) do
      {:ok, charged} ->
        rewarded = restore_sp(charged, reward)
        new_state = commit_cast(state, rewarded, descriptor.skill_id, descriptor.level)
        broadcast_skill_use(rewarded, descriptor.skill_id, descriptor.level, descriptor.target)
        maybe_resume_lock(new_state, locked)

      {:error, _reason} ->
        maybe_resume_lock(%{state | game_state: game_state}, locked)
    end
  end

  defp resolve_deferred(
         state,
         game_state,
         %Interpreter.Deferred{effect: {:transfer_sphere, target_id}} = descriptor,
         locked
       ) do
    case Interpreter.settle_deferred(game_state, descriptor) do
      {:ok, charged} ->
        new_state = commit_cast(state, charged, descriptor.skill_id, descriptor.level)
        broadcast_skill_use(charged, descriptor.skill_id, descriptor.level, descriptor.target)
        SpiritExchangeHandler.transfer(new_state, target_id)
        maybe_resume_lock(new_state, locked)

      {:error, _reason} ->
        maybe_resume_lock(%{state | game_state: game_state}, locked)
    end
  end

  defp resolve_deferred(
         state,
         game_state,
         %Interpreter.Deferred{effect: {:absorb_player, target_id}} = descriptor,
         locked
       ) do
    token = make_ref()
    timer_ref = Process.send_after(self(), {:deferred_skill_timeout, token}, 1_000)

    state =
      state
      |> Map.put(:game_state, game_state)
      |> Map.put(:deferred_skill_result, %{
        descriptor: descriptor,
        target_id: target_id,
        token: token,
        timer_ref: timer_ref,
        combat_target_id: locked
      })

    SpiritExchangeHandler.request_absorb(state, target_id, token)
    state
  end

  defp resolve_deferred(state, game_state, _descriptor, locked) do
    maybe_resume_lock(%{state | game_state: game_state}, locked)
  end

  defp cancel_deferred_timer(%{timer_ref: timer_ref}) when is_reference(timer_ref) do
    Process.cancel_timer(timer_ref)
    :ok
  end

  defp cancel_deferred_timer(_pending), do: :ok

  defp restore_sp(game_state, amount) do
    stats = game_state.stats
    max_sp = stats.derived_stats.max_sp
    current = %{stats.current_state | sp: min(stats.current_state.sp + amount, max_sp)}
    %{game_state | stats: %{stats | current_state: current}}
  end

  @doc """
  Re-dispatches the pending skill after the move-to-range approach completes.

  The skill (id, level, target) is carried in `state_context` while walking. We
  drop back to idle and run the normal cast dispatch: if the target is now in
  range it casts, if it drifted further it re-approaches, and if it vanished the
  cast quietly fails.
  """
  @spec handle_reached_skill_position(SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_reached_skill_position(
        %{
          game_state:
            %{state_context: %{skill_id: skill_id, skill_level: level, target: target} = ctx} =
              game_state
        } = state
      ) do
    # Restore the pre-walk lock onto the freshly-idled state so drive_cast's
    # capture carries it forward and the auto-attack loop resumes after the cast.
    idled = %{to_idle(game_state) | combat_target_id: Map.get(ctx, :combat_target_id)}
    drive_cast(%{state | game_state: idled}, skill_id, level, target)
  end

  def handle_reached_skill_position(%{game_state: game_state} = state) do
    {:noreply, %{state | game_state: to_idle(game_state)}}
  end

  # Starts walking the caster to within skill range of the target. Gives up
  # (leaving the player idle) when the target is gone, no closer cell exists, or
  # no path reaches it — never loops.
  defp initiate_skill_movement(%{game_state: game_state} = state, skill_id, level, target, locked) do
    with :ok <- ensure_living_target(target),
         {:ok, target_pos} <- skill_target_position(target),
         {:ok, definition} <- Catalog.by_id(skill_id),
         {:ok, map_data} <- MapCache.get(game_state.map_name) do
      range = Interpreter.effective_range(definition, game_state)
      current = {game_state.x, game_state.y}
      optimal = CombatActionHandler.get_optimal_attack_position(current, target_pos, range)

      move_toward_skill_target(state, skill_id, level, target, current, optimal, map_data, locked)
    else
      _ ->
        report_cast_failure(skill_id, game_state.character_id, :out_of_range)
        {:noreply, state}
    end
  end

  # Optimal cell equals the current cell: no closer approach exists, so stop
  # rather than re-issue a zero-length move and spin.
  defp move_toward_skill_target(
         state,
         skill_id,
         _level,
         _target,
         current,
         current,
         _map_data,
         _locked
       ) do
    report_cast_failure(skill_id, state.game_state.character_id, :out_of_range)
    {:noreply, state}
  end

  defp move_toward_skill_target(
         state,
         skill_id,
         level,
         target,
         current,
         optimal,
         map_data,
         locked
       ) do
    case Pathfinding.find_path(map_data, current, optimal) do
      {:ok, [_ | _]} ->
        start_skill_approach(state, skill_id, level, target, optimal, locked)

      _ ->
        report_cast_failure(skill_id, state.game_state.character_id, :no_path)
        {:noreply, state}
    end
  end

  defp start_skill_approach(
         %{game_state: game_state} = state,
         skill_id,
         level,
         target,
         {x, y},
         locked
       ) do
    context = %{skill_id: skill_id, skill_level: level, target: target, combat_target_id: locked}

    case PlayerState.transition_to(game_state, :skill_moving, context) do
      {:ok, moving_state} ->
        MovementHandler.handle_request_move(
          %{state | game_state: moving_state},
          x,
          y,
          skill_initiated: true
        )

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  defp skill_target_position({:unit, target_id}) do
    case resolve_unit_position(target_id) do
      {:ok, {x, y, _map}} -> {:ok, {x, y}}
      {:error, _} -> :error
    end
  end

  defp skill_target_position({:ground, x, y}), do: {:ok, {x, y}}
  # A self-target is always in range, so it never reaches the move-to-range path.
  defp skill_target_position(:self), do: :error

  defp resolve_unit_position(unit_id) do
    case SpatialIndex.get_unit_position(:player, unit_id) do
      {:ok, _} = ok -> ok
      {:error, :not_found} -> SpatialIndex.get_unit_position(:mob, unit_id)
    end
  end

  defp ensure_living_target({:unit, unit_id}) do
    case TargetResolver.resolve(unit_id) do
      {:ok, _pid, target_state, unit_type} ->
        TargetResolver.ensure_targetable(target_state, unit_type)

      {:error, _reason} ->
        :ok
    end
  end

  defp ensure_living_target(_target), do: :ok

  # A cast may only begin from idle. A moving player is stopped first (using a
  # skill ends movement); any other busy state (casting, attacking, sitting,
  # trading, vending) aborts so a player can't act while a cast is in flight or
  # stack a second action on top of a busy one. An in-flight cast descriptor
  # rejects regardless of action_state, so a cast that overlays another state
  # can never stack a second cast.
  defp ensure_idle_for_cast(%{game_state: %{casting: casting}}) when not is_nil(casting),
    do: :busy

  defp ensure_idle_for_cast(%{game_state: %{action_state: :idle}} = state), do: {:ok, state}

  defp ensure_idle_for_cast(%{game_state: %{action_state: moving}} = state)
       when moving in [:moving, :combat_moving, :skill_moving, :moving_to_item] do
    {:noreply, stopped_state} = MovementHandler.handle_force_stop_movement(state)

    case PlayerState.transition_to(stopped_state.game_state, :idle) do
      {:ok, idle_game_state} -> {:ok, %{stopped_state | game_state: idle_game_state}}
      {:error, _reason} -> :busy
    end
  end

  # A player mid-swing in the auto-attack loop sits in :attacking between swings.
  # Casting from there is legal: drop through :idle (a valid transition that
  # cancels the pending swing) so the cast starts, then resume the loop after.
  defp ensure_idle_for_cast(%{game_state: %{action_state: :attacking}} = state) do
    case PlayerState.transition_to(state.game_state, :idle) do
      {:ok, idle_game_state} -> {:ok, %{state | game_state: idle_game_state}}
      {:error, _reason} -> :busy
    end
  end

  defp ensure_idle_for_cast(_state), do: :busy

  defp schedule_cast(%{game_state: game_state} = state, info, locked) do
    now = System.monotonic_time(:millisecond)
    token = make_ref()
    timer_ref = Process.send_after(self(), {:skill, {:cast_complete, token}}, info.total)

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
      interruptible: true,
      combat_target_id: locked
    }

    case PlayerState.transition_to(game_state, :casting, context) do
      {:ok, casting_state} ->
        broadcast_cast_bar(casting_state, info)
        {:noreply, %{state | game_state: casting_state}}

      {:error, reason} ->
        Process.cancel_timer(timer_ref)
        report_cast_failure(info.skill_id, game_state.character_id, reason)
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

  # A cast's resolution point: completion, cancellation, interruption.
  #
  # The descriptor is cleared explicitly rather than left to a `transition_to/3`
  # edge — Free Cast overlays a cast on `:moving` or `:attacking`, so no single
  # edge owns the clearing.
  #
  # A standing cast *is* the player's action, so resolving it returns them to
  # `:idle`. An overlaid one is not: the walk or the auto-attack loop underneath
  # it is the player's actual action and outlives the cast, so the action state is
  # left alone. Dropping it to `:idle` there would silently stop the walk and
  # clear the combat intent the loop runs on.
  defp end_cast(%{action_state: :casting} = game_state) do
    game_state |> to_idle() |> PlayerState.clear_casting()
  end

  defp end_cast(game_state), do: PlayerState.clear_casting(game_state)

  # Skills count as engaging in combat: after a cast the player keeps attacking
  # the target that was locked when the cast began. Re-set combat intent and hand
  # the target back to the combat auto-attack loop. No lock (idle caster) or a
  # dead target means no resume, so a lone skill never starts a spurious loop. The
  # lock survives instant casts, timed casts, a walk-into-range (skill_moving), and
  # a damage interrupt.
  defp maybe_resume_lock(state, nil), do: state

  defp maybe_resume_lock(%{game_state: game_state} = state, target_id) do
    if target_alive?(target_id) do
      timer_ref = Process.send_after(self(), {:combat, {:auto_attack, target_id}}, 0)

      game_state =
        game_state
        |> PlayerState.set_combat_intent(target_id, 7)
        |> PlayerState.set_continuous_timer(timer_ref)

      %{state | game_state: game_state}
    else
      state
    end
  end

  defp target_alive?(target_id), do: match?({:ok, _}, resolve_unit_position(target_id))

  # Shared success path: calculate the final player state, commit it to the
  # registry, then perform every outward effect. The committed state is the gate
  # for persistence, packets, timer work, and staged follow-up actions.
  # `postdelay?` is false for the auto-cast path only: the SkillCooldown packet
  # announces the cooldown the interpreter just wrote, and `auto_cast/4` writes
  # none, so sending it would grey out a bolt the server still considers ready.
  defp commit_cast(
         %{connection_pid: connection_pid} = state,
         new_game_state,
         skill_id,
         level,
         postdelay? \\ true
       ) do
    previous_spheres = state.game_state.spirit_spheres
    equipped = Map.values(Inventory.equipped_items(new_game_state.inventory))

    updated_stats =
      Stats.calculate_stats(new_game_state.stats, new_game_state.character_id, equipped)

    new_game_state = %{new_game_state | stats: updated_stats}

    {new_game_state, sphere_cost_plan} =
      SpiritSphereHandler.prepare_skill_cost(new_game_state, previous_spheres)

    state = StateCommit.commit(state, new_game_state)

    state =
      update_in(state.game_state, fn game_state ->
        InventoryStaging.drain(connection_pid, game_state)
      end)

    game_state = state.game_state

    CharacterPersistence.update_character(
      game_state.character_id,
      %{
        hp: game_state.stats.current_state.hp,
        sp: game_state.stats.current_state.sp,
        zeny: game_state.zeny
      },
      async: true
    )

    StatusSync.send_stat_updates(connection_pid, game_state.stats)
    StatusSync.send_param(connection_pid, StatusParams.zeny(), game_state.zeny)

    if postdelay?, do: maybe_send_postdelay(connection_pid, skill_id, level)

    state
    |> SpiritSphereHandler.apply_skill_cost_effects(sphere_cost_plan)
    |> drain_warp()
    |> drain_interaction()
    |> drain_menu_offer()
  end

  # Sends the SkillMenu a cast staged on pending_menu_offer (SA_AUTOSPELL's bolt
  # list) and parks it on the session. Drained after the cast commits, so the SP
  # is already spent by the time the client can answer - and a reply that never
  # comes simply leaves the offer to be cleared by death, warp or disconnect.
  defp drain_menu_offer(%{game_state: %{pending_menu_offer: nil}} = state), do: state

  defp drain_menu_offer(%{game_state: game_state} = state) do
    %{skill_id: skill_id, kind: kind, entry_ids: entry_ids, level: level} =
      game_state.pending_menu_offer

    %{state | game_state: %{game_state | pending_menu_offer: nil}}
    |> SkillMenuHandler.open(skill_id, kind, entry_ids, level)
  end

  @doc """
  Runs a bolt SA_AUTOSPELL's proc armed, cast to this session by the combat path
  once the triggering weapon hit committed.

  The restricted interpreter entry does the mechanics (2/3 SP, no cast time, no
  catalyst, aftercast delay); this commits the result the way a real cast does, so
  the drained SP is persisted and synced. A proc that fizzles - almost always
  insufficient SP - leaves the session untouched and tells the player nothing,
  which is rAthena's behaviour.
  """
  @spec handle_auto_cast(SessionState.t(), integer(), pos_integer(), Active.target()) ::
          {:noreply, SessionState.t()}
  def handle_auto_cast(%{game_state: game_state} = state, skill_id, level, target) do
    case Interpreter.auto_cast(game_state, skill_id, level, target) do
      {:ok, new_game_state} ->
        new_state = commit_cast(state, new_game_state, skill_id, level, false)
        broadcast_skill_use(new_state.game_state, skill_id, level, target)
        {:noreply, new_state}

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  # Synthetic gid stamped on skill-triggered dialogs (AC_MAKINGARROW's crafting
  # menu). Outside every real unit-id range (warps 0x4000_0000.., NPCs
  # 0x5000_0000..0x57FF_FFFF) so it can never collide with a spawned unit; the
  # client only echoes it back on NpcInteract.
  @system_dialog_gid 0x6000_0000

  # Starts the Script.Interaction a skill staged on pending_interaction (the
  # same lock-and-monitor wiring as NpcInteractionHandler.talk_to_npc). Dropped
  # when a dialog is already active, mirroring the NPC-click guard.
  defp drain_interaction(%{game_state: %{pending_interaction: nil}} = state), do: state

  defp drain_interaction(%{game_state: game_state, interaction_lock: lock} = state)
       when not is_nil(lock) do
    %{state | game_state: %{game_state | pending_interaction: nil}}
  end

  defp drain_interaction(%{game_state: game_state} = state) do
    module = game_state.pending_interaction
    clean_game_state = %{game_state | pending_interaction: nil}

    base_ctx =
      Ctx.from_session(
        %{game_state: clean_game_state, connection_pid: state.connection_pid},
        {:npc, module}
      )

    base_ctx = %{base_ctx | npc_gid: @system_dialog_gid}
    {:ok, pid} = Interaction.start(self(), module, base_ctx)
    ref = Process.monitor(pid)

    %{state | game_state: clean_game_state, interaction_lock: {pid, ref, @system_dialog_gid}}
  end

  # Executes any warp directive the skill staged on pending_warp (SP and
  # cooldowns are already committed at this point). Clears the field before
  # calling WarpHandler so the warp state is clean. On error the directive is
  # still cleared to avoid re-triggering on a subsequent cast.
  defp drain_warp(%{game_state: game_state} = state) do
    case game_state.pending_warp do
      nil ->
        state

      {dest_map, x, y} ->
        clean_game_state = %{game_state | pending_warp: nil}

        case WarpHandler.warp(%{state | game_state: clean_game_state}, dest_map, x, y) do
          {:ok, new_state} -> new_state
          {:error, _reason} -> %{state | game_state: clean_game_state}
        end
    end
  end

  defp report_cast_failure(skill_id, character_id, reason) do
    Logger.debug("Skill #{skill_id} cast failed for #{character_id}: #{inspect(reason)}")

    Broadcast.to_player(character_id, %SkillCastFailed{
      skill_id: skill_id,
      reason: failure_reason(reason)
    })
  end

  defp failure_reason(:missing_catalyst), do: :SKILL_CAST_FAILURE_REASON_MISSING_CATALYST
  defp failure_reason(:insufficient_sp), do: :SKILL_CAST_FAILURE_REASON_INSUFFICIENT_SP
  defp failure_reason(:insufficient_zeny), do: :SKILL_CAST_FAILURE_REASON_INSUFFICIENT_ZENY
  defp failure_reason(:no_ammo), do: :SKILL_CAST_FAILURE_REASON_NO_AMMO
  defp failure_reason(:on_cooldown), do: :SKILL_CAST_FAILURE_REASON_ON_COOLDOWN

  defp failure_reason(reason) when reason in [:invalid_target, :different_map, :target_not_found],
    do: :SKILL_CAST_FAILURE_REASON_INVALID_TARGET

  defp failure_reason(:skill_not_learned), do: :SKILL_CAST_FAILURE_REASON_NOT_LEARNED

  defp failure_reason(reason) when reason in [:out_of_range, :no_path],
    do: :SKILL_CAST_FAILURE_REASON_OUT_OF_RANGE

  defp failure_reason(:busy), do: :SKILL_CAST_FAILURE_REASON_BUSY
  defp failure_reason(_reason), do: :SKILL_CAST_FAILURE_REASON_UNSPECIFIED

  defp resolve_target(%{character_id: caster_id}, target_id) when target_id == caster_id,
    do: :self

  defp resolve_target(_game_state, target_id), do: {:unit, target_id}

  defp maybe_cancel_combo(state, skill_id) when skill_id in @combo_followup_ids, do: state

  defp maybe_cancel_combo(%{game_state: game_state} = state, _skill_id) do
    %{state | game_state: PlayerState.cancel_combo(game_state)}
  end

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
