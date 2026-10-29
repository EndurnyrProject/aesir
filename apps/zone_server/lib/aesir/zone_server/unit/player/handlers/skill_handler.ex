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
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillCasting
  alias Aesir.Net.SkillCooldown
  alias Aesir.Net.SkillEffect
  alias Aesir.Net.SystemNotice
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutocast
  alias Aesir.ZoneServer.Mmo.Combat.EquipProcDispatch
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.CastEnd
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandler, as: HomunculusCommandHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.LifecycleSkillHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.PrivateStateView
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit, as: HomunculusStateCommit
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryStaging
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillTextInputHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SpiritExchangeHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SpiritSphereHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.Player.Logout
  alias Aesir.ZoneServer.Unit.Player.PlayerEvents
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.SkillRequest
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # SA_CASTCANCEL cancels the caster's own in-flight cast, so it is the one skill
  # a request may use while casting. It is intercepted ahead of `drive_cast/4`
  # (and therefore ahead of `ensure_idle_for_cast/1`, which would reject it) and
  # never takes the ordinary cast path.
  @cast_cancel_id 275
  @encore_id 305
  @brandish_spear 57
  @pharmacy 228
  @pharmacy_menu_refused [228, 147, 108, 496, 497, 498]
  @auto_counter 61
  @divest_skills [215, 216, 217, 218, 476]
  @overlaid_states [:sitting, :trading]
  @arrow_vulcan_id 394

  @doc """
  Handles a player's request to use a skill on a unit. `SkillRequest.targeted/5`
  decides it: a refusal sends its reply, and a request that passes ends the
  invincibility where it should and runs at its decided level, from the
  pending item skill when it names one. A request decided at level 0 casts
  nothing. The cast's own gate then refuses silently a dead caster or one a
  status forbids from using the skill.
  """
  @spec handle_use_skill(SessionState.t(), integer(), non_neg_integer(), integer() | tuple()) ::
          {:noreply, SessionState.t()}
  def handle_use_skill(state, skill_id, level, target_id) do
    now = System.monotonic_time(:millisecond)

    case SkillRequest.targeted(state, skill_id, level, target_id, now) do
      {:refuse, reply} -> send_request_reply(state, skill_id, reply)
      {:use, request} -> state |> accept_request(request) |> run_targeted(skill_id, request)
    end
  end

  defp run_targeted(state, _skill_id, %{level: 0}), do: {:noreply, state}

  defp run_targeted(state, skill_id, %{origin: :item, level: level, target: target_id}),
    do: drive_item_cast(state, skill_id, level, resolve_target(state.game_state, target_id))

  defp run_targeted(state, skill_id, %{level: level, target: target_id}),
    do: dispatch_use_skill(state, skill_id, level, target_id)

  # A request that passed ends the invincibility when it should and leaves a
  # pending item skill behind only for an item skill.
  defp accept_request(state, request) do
    state = if request.ends_invincibility?, do: Invincibility.stop(state), else: state

    if request.clears_item_skill? and Map.get(state, :pending_item_skill) != nil,
      do: %{state | pending_item_skill: nil},
      else: state
  end

  defp send_request_reply(state, skill_id, reply) do
    report_cast_failure(skill_id, state.game_state.character_id, {:not_ok, reply})
    {:noreply, state}
  end

  defp dispatch_use_skill(state, @cast_cancel_id, level, _target_id) do
    case cast_gate(state, @cast_cancel_id, :restricted) do
      {:ok, ready_state} ->
        cast_cancel(ready_state, level)

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  defp dispatch_use_skill(%{game_state: game_state} = state, skill_id, level, target_id) do
    target = resolve_target(game_state, target_id)
    locked = game_state.combat_target_id

    case cast_gate(state, skill_id, :request) do
      {:ok, ready_state} ->
        drive_cast_after_gate(ready_state, skill_id, level, target, locked)

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  # Mirrors rAthena's ordering (`skills/mage/castcancel.cpp`): the requirement is
  # consumed first, then the cast is aborted, then the penalty is zapped. Running
  # `begin_cast/4` up front validates Cast Cancel (learned, cooldown, its own 2 SP)
  # and charges it against a state that still carries the descriptor, so a Cast
  # Cancel the player cannot afford aborts nothing. With no cast in flight,
  # `SaCastcancel.begin_attempt/4` rejects `:not_casting` here and charges nothing.
  #
  # `begin_cast/4` only reads the cast descriptor, so it is safe to run before the
  # abort; the cancel then invalidates the token before the zap is applied, and a
  # single `commit_cast/4` publishes both SP deltas at once.
  defp cast_cancel(%{game_state: game_state} = state, level) do
    case Interpreter.begin_cast(
           stamp_cast_context(state, game_state),
           @cast_cancel_id,
           level,
           :self
         ) do
      {:instant, charged_game_state} ->
        state = Logout.stamp(state)
        sync_cast_start_stats(state, game_state, charged_game_state)
        penalty = cast_cancel_penalty(game_state.casting, level)

        cancelled_state = cancel_cast(%{state | game_state: charged_game_state}, :castcancel)
        zapped_game_state = zap_sp(cancelled_state.game_state, penalty)

        new_state = commit_cast(cancelled_state, zapped_game_state, @cast_cancel_id, level)
        broadcast_skill_use(new_state.game_state, @cast_cancel_id, level, :self)
        {:noreply, new_state}

      {:error, reason, refreshed} ->
        {:noreply, commit_failed_attempt(state, game_state, refreshed, @cast_cancel_id, reason)}

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

  @doc """
  Handles a player's request to use a ground skill on the cell `(x, y)`.
  `SkillRequest.ground/5` decides it as `handle_use_skill/4` does; it refuses
  the request while the player sits, trades or otherwise cannot act.
  """
  @spec handle_use_skill_ground(
          SessionState.t(),
          integer(),
          non_neg_integer(),
          integer(),
          integer()
        ) ::
          {:noreply, SessionState.t()}
  def handle_use_skill_ground(state, skill_id, level, x, y) do
    now = System.monotonic_time(:millisecond)

    case SkillRequest.ground(state, skill_id, level, {x, y}, now) do
      {:refuse, reply} -> send_request_reply(state, skill_id, reply)
      {:use, request} -> state |> accept_request(request) |> run_ground(skill_id, request)
    end
  end

  defp run_ground(state, _skill_id, %{level: 0}), do: {:noreply, state}

  defp run_ground(state, skill_id, %{origin: :item, level: level, target: {x, y}}),
    do: drive_item_cast(state, skill_id, level, {:ground, x, y})

  defp run_ground(%{game_state: game_state} = state, skill_id, %{level: level, target: {x, y}}) do
    locked = game_state.combat_target_id

    case cast_gate(state, skill_id, :request) do
      {:ok, ready_state} ->
        drive_ground_request(ready_state, skill_id, level, {:ground, x, y}, locked)

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  defp drive_ground_request(ready_state, skill_id, level, target, locked) do
    if SkillTextInputHandler.input_required?(skill_id) do
      SkillTextInputHandler.stage(ready_state, skill_id, level, target)
    else
      drive_cast_after_gate(ready_state, skill_id, level, target, locked)
    end
  end

  @doc "Completes a staged input cast after rerunning the session and interpreter gates."
  @spec complete_cast_with_input(
          SessionState.t(),
          integer(),
          pos_integer(),
          Active.target(),
          term()
        ) ::
          {:noreply, SessionState.t()}
  def complete_cast_with_input(state, skill_id, level, target, input) do
    with {:ok, gated_state} <- cast_gate(state, skill_id),
         {:ok, ready_state} <- ensure_idle_for_cast(gated_state) do
      complete_input_cast(ready_state, skill_id, level, target, input)
    else
      :busy -> reject_cast_gate(state, skill_id, :busy)
      {:error, reason} -> reject_cast_gate(state, skill_id, reason)
    end
  end

  defp complete_input_cast(state, skill_id, level, target, input) do
    result =
      Interpreter.complete_cast_with_input(
        stamp_cast_context(state, state.game_state),
        skill_id,
        level,
        target,
        input
      )

    state = stamp_if_begun(state, result)

    case result do
      {:ok, new_game_state} ->
        new_game_state = dispatch_committed_action(state, new_game_state, skill_id)
        new_state = commit_cast(state, new_game_state, skill_id, level)
        broadcast_skill_use(new_state.game_state, skill_id, level, target)
        {:noreply, new_state}

      {:deferred, new_game_state, descriptor} ->
        new_game_state = dispatch_committed_action(state, new_game_state, skill_id)
        {:noreply, resolve_deferred(state, new_game_state, descriptor)}

      {:failed, new_game_state, reason} ->
        new_game_state = dispatch_committed_action(state, new_game_state, skill_id)
        {:noreply, commit_spent_failure(state, new_game_state, skill_id, level, target, reason)}

      {:failed, new_game_state, reason, variant} ->
        new_game_state = dispatch_committed_action(state, new_game_state, skill_id)

        {:noreply,
         commit_variant_failure(variant, state, new_game_state, {skill_id, level, target}, reason)}

      {:skipped, new_game_state, _reason} ->
        new_game_state = dispatch_committed_action(state, new_game_state, skill_id)
        {:noreply, commit_skipped_use(state, new_game_state, skill_id, level)}

      {:castend_failed, new_game_state, reason} ->
        {:noreply, commit_castend_failure(state, new_game_state, skill_id, level, reason)}

      {:error, reason} ->
        report_cast_failure(skill_id, state.game_state.character_id, reason)
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

    case cast_gate(state, ctx.skill_id, :completion) do
      {:ok, ready_state} ->
        complete_cast(ready_state, ready_state.game_state, ctx)

      {:error, _reason} ->
        broadcast_cast_cancel(game_state)
        {:noreply, %{state | game_state: end_cast(game_state)}}
    end
  end

  def handle_cast_complete(state, _token), do: {:noreply, state}

  defp complete_cast(state, game_state, ctx) do
    expected_id = Map.get(ctx, :homunculus_id)
    game_state = stamp_cast_context(state, game_state)

    result =
      case Map.get(ctx, :origin) do
        :item ->
          Interpreter.complete_item_cast(
            game_state,
            ctx.skill_id,
            ctx.skill_level,
            ctx.target,
            Map.get(ctx, :keep_requirement?, false)
          )

        :script ->
          Interpreter.complete_script_cast(
            game_state,
            ctx.skill_id,
            ctx.skill_level,
            ctx.target
          )

        :encore ->
          Interpreter.complete_encore_replay(game_state, ctx.memory, ctx.target)

        _ ->
          Interpreter.complete_cast(game_state, ctx.skill_id, ctx.skill_level, ctx.target)
      end

    resolve_completion(state, game_state, ctx, expected_id, result)
  end

  defp resolve_completion(state, game_state, ctx, expected_id, result) do
    case result do
      {:ok, new_game_state} ->
        new_state = commit_cast(state, new_game_state, ctx.skill_id, ctx.skill_level)
        broadcast_skill_use(new_state.game_state, ctx.skill_id, ctx.skill_level, ctx.target)
        resolved_state = %{new_state | game_state: end_cast(new_state.game_state)}
        {:noreply, resolved_state}

      {:local_effects, new_game_state, effects} ->
        new_state =
          state
          |> commit_cast(new_game_state, ctx.skill_id, ctx.skill_level)
          |> settle_local_effects(effects)

        broadcast_skill_use(new_state.game_state, ctx.skill_id, ctx.skill_level, ctx.target)
        resolved_state = %{new_state | game_state: end_cast(new_state.game_state)}
        {:noreply, resolved_state}

      {:deferred, new_game_state, descriptor} ->
        {:noreply, resolve_deferred(state, end_cast(new_game_state), descriptor, expected_id)}

      {:failed, new_game_state, reason} ->
        new_state =
          commit_spent_failure(
            state,
            new_game_state,
            ctx.skill_id,
            ctx.skill_level,
            ctx.target,
            reason
          )

        resolved_state = %{new_state | game_state: end_cast(new_state.game_state)}
        {:noreply, resolved_state}

      {:failed, new_game_state, reason, variant} ->
        new_state =
          commit_variant_failure(
            variant,
            state,
            new_game_state,
            {ctx.skill_id, ctx.skill_level, ctx.target},
            reason
          )

        resolved_state = %{new_state | game_state: end_cast(new_state.game_state)}
        {:noreply, resolved_state}

      {:skipped, new_game_state, _reason} ->
        new_state = commit_skipped_use(state, new_game_state, ctx.skill_id, ctx.skill_level)
        resolved_state = %{new_state | game_state: end_cast(new_state.game_state)}
        {:noreply, resolved_state}

      {:castend_failed, new_game_state, reason} ->
        new_state =
          commit_castend_failure(state, new_game_state, ctx.skill_id, ctx.skill_level, reason)

        {:noreply, %{new_state | game_state: end_cast(new_state.game_state)}}

      {:error, reason} ->
        reject_completed_cast(state, game_state, ctx.skill_id, reason)
    end
  end

  # The effect failed after its requirement was spent: the spend commits like a
  # cast and the use still closes, but the caster sees the failure instead of
  # the skill.
  defp commit_spent_failure(state, new_game_state, skill_id, level, target, reason) do
    new_state = commit_cast(state, new_game_state, skill_id, level)
    report_cast_failure(skill_id, new_state.game_state.character_id, reason)
    CastEnd.complete(new_state.game_state, skill_id, target)
    new_state
  end

  # A four-element failure: an effect that shows itself before failing
  # (`:after_effect`), or a failure that paid only its requirement.
  defp commit_variant_failure(
         :after_effect,
         state,
         new_game_state,
         {skill_id, level, target},
         reason
       ),
       do: commit_shown_failure(state, new_game_state, skill_id, level, target, reason)

  defp commit_variant_failure(
         _variant,
         state,
         new_game_state,
         {skill_id, level, _target},
         reason
       ),
       do: commit_requirement_only_failure(state, new_game_state, skill_id, level, reason)

  # An effect that shows itself before failing (`:after_effect`): the skill's
  # effect goes out first, then the cast commits like a spent failure (its staged
  # production result included) and the failure is reported.
  defp commit_shown_failure(state, new_game_state, skill_id, level, target, reason) do
    broadcast_skill_effect(new_game_state, skill_id, level, target)
    new_state = commit_cast(state, new_game_state, skill_id, level)
    report_cast_failure(skill_id, new_state.game_state.character_id, reason)
    CastEnd.complete(new_state.game_state, skill_id, target)
    new_state
  end

  # The reference pays the requirement but arms neither the after-cast delay nor
  # the cooldown and never runs the cast-end tail (the Emperium refusal, a
  # blocked walk path): the spend commits, the caster sees the failure.
  defp commit_requirement_only_failure(state, new_game_state, skill_id, level, reason) do
    new_state = commit_cast(state, new_game_state, skill_id, level, false)
    report_cast_failure(skill_id, new_state.game_state.character_id, reason)
    %{new_state | game_state: end_cast(new_state.game_state)}
  end

  # The reference ends a use whose target died before its effect: the paid
  # requirement and the after-cast delay stay, the effect and its cast-end tail
  # do not run, and the caster sees no failure.
  defp commit_skipped_use(state, new_game_state, skill_id, level) do
    new_state = commit_cast(state, new_game_state, skill_id, level)
    %{new_state | game_state: end_cast(new_state.game_state)}
  end

  # A cast end refused by a cast-end check whose skill reacts to the failure
  # (Asura Strike): what it spent and did commits like a cast, with no
  # aftercast display or cast-end tail, and the caster sees the failure.
  defp commit_castend_failure(state, new_game_state, skill_id, level, reason) do
    new_state = commit_cast(state, new_game_state, skill_id, level, false)
    report_cast_failure(skill_id, new_state.game_state.character_id, reason)
    new_state
  end

  defp reject_completed_cast(state, game_state, skill_id, reason) do
    report_cast_failure(skill_id, game_state.character_id, reason)
    {:noreply, %{state | game_state: end_cast(game_state)}}
  end

  @doc """
  Damage interruption: active damage cancels a timed cast in any phase when its
  skill can be cancelled (`cast_cancel`, captured as `interruptible`), unless
  `bNoCastCancel2` equipment is worn, or `bNoCastCancel` equipment off siege
  ground. Anything else passes through unchanged.
  """
  @spec interrupt_cast_on_damage(SessionState.t()) :: SessionState.t()
  def interrupt_cast_on_damage(
        %{game_state: %{casting: %{interruptible: true}} = game_state} = state
      ) do
    if cast_cancel_immune?(game_state), do: state, else: cancel_cast(state, :damage)
  end

  def interrupt_cast_on_damage(state), do: state

  defp cast_cancel_immune?(%{stats: stats, map_name: map_name}) do
    Stats.get_equipment_modifier(stats, :no_cast_cancel2) > 0 or
      (Stats.get_equipment_modifier(stats, :no_cast_cancel) > 0 and not Rules.ground?(map_name))
  end

  defp cast_cancel_immune?(_game_state), do: false

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
        _reason
      ) do
    Process.cancel_timer(ctx.timer_ref)
    broadcast_cast_cancel(game_state)

    StateCommit.commit(state, end_cast(game_state))
  end

  def cancel_cast(state, _reason), do: state

  @doc """
  Cancels the player's in-flight cast on another unit's request (Mind Breaker,
  Spell Breaker), phase-agnostic. A player with no cast in flight is returned
  unchanged.
  """
  @spec interrupt_cast(SessionState.t()) :: {:noreply, SessionState.t()}
  def interrupt_cast(state), do: {:noreply, cancel_cast(state, :interrupted)}

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

  defp drive_cast_after_gate(state, skill_id, level, target, locked, opts \\ []) do
    cond do
      not cast_ready?(state, opts) -> reject_cast_gate(state, skill_id, :busy)
      state.deferred_skill_result -> reject_cast_gate(state, skill_id, :busy)
      true -> attempt_use(state, skill_id, level, target, locked, opts)
    end
  end

  # A standing player's request begins the cast; out of range, it starts a walk
  # toward the target on the client's behalf and is remembered
  # (`handle_begin_error/7`). A walking player's use, and a remembered use tried
  # again (`approach?: false`), is first checked as far as its range on the
  # player as they are (`Interpreter.walking_attempt/4`): one that would start
  # stops the walk and begins for real; one the walking player does not reach
  # yet is remembered; one out of range after the walk is dropped. Every other
  # refusal answers as the cast would and leaves the walk alone.
  defp attempt_use(%{game_state: game_state} = state, skill_id, level, target, locked, opts) do
    {aimed, combo?} = aim_use(game_state, skill_id, level, target, locked)
    # A combo used while swinging at its target has the attack's reach.
    opts =
      opts
      |> Keyword.put(:attack_reach, combo? and game_state.action_state == :attacking)

    checked? = game_state.movement_state == :moving or not Keyword.get(opts, :approach?, true)

    if checked?,
      do: checked_use(state, skill_id, level, aimed, locked, opts),
      else: start_use(state, skill_id, level, aimed, locked, opts)
  end

  @doc """
  Copies the owner's homunculus lifecycle and HP onto `game_state`, where the
  homunculus skills' cast checks read it.
  """
  @spec stamp_homunculus(SessionState.t() | map(), PlayerState.t()) :: PlayerState.t()
  def stamp_homunculus(state, game_state) do
    case Map.get(state, :homunculus) do
      nil ->
        %{game_state | homunculus_summary: nil}

      homunculus ->
        summary = %{lifecycle: homunculus.lifecycle, hp: homunculus.hp, max_hp: homunculus.max_hp}
        %{game_state | homunculus_summary: summary}
    end
  end

  # The session context a cast reads from the game state: the homunculus summary
  # and the open skill menu's source skill (0 for none).
  defp stamp_cast_context(state, game_state) do
    menu_skill_id =
      case Map.get(state, :pending_skill_menu) do
        %{skill_id: skill_id} -> skill_id
        _none -> 0
      end

    %{stamp_homunculus(state, game_state) | open_menu_skill_id: menu_skill_id}
  end

  defp checked_use(%{game_state: game_state} = state, skill_id, level, aimed, locked, opts) do
    case walking_attempt(stamp_cast_context(state, game_state), skill_id, level, aimed, opts) do
      :in_range ->
        start_use(state, skill_id, level, aimed, locked, opts)

      {:step, refreshed} ->
        state
        |> commit_failed_attempt(game_state, refreshed, skill_id, :step_action)
        |> remember_step(skill_id, level, aimed, locked)
        |> then(&{:noreply, &1})

      {:error, reason, refreshed} ->
        {:noreply, commit_failed_attempt(state, game_state, refreshed, skill_id, reason)}
    end
  end

  # A combo with the attack's reach keeps its attack running; any other cast ends
  # it as it begins (`Interpreter.begin_cast/5`). Nothing resumes an attack after
  # a cast: a chase the cast stopped stays stopped.
  defp start_use(state, skill_id, level, target, locked, opts) do
    state = %{state | step_action: nil}

    case ensure_idle_for_cast(state, opts) do
      {:ok, ready} ->
        result =
          begin_cast(stamp_cast_context(ready, ready.game_state), skill_id, level, target, opts)

        handle_begin_result(ready, ready.game_state, skill_id, level, target, locked, result)

      :busy ->
        reject_cast_gate(state, skill_id, :busy)
    end
  end

  # Only a combo with the attack's reach passes options to the interpreter.
  defp walking_attempt(game_state, skill_id, level, target, opts) do
    if Keyword.get(opts, :attack_reach, false),
      do: Interpreter.walking_attempt(game_state, skill_id, level, target, attack_reach: true),
      else: Interpreter.walking_attempt(game_state, skill_id, level, target)
  end

  defp begin_cast(game_state, skill_id, level, target, opts) do
    if Keyword.get(opts, :attack_reach, false),
      do: Interpreter.begin_cast(game_state, skill_id, level, target, attack_reach: true),
      else: Interpreter.begin_cast(game_state, skill_id, level, target)
  end

  defp remember_step(state, skill_id, level, target, locked) do
    step = %{
      skill_id: skill_id,
      level: level,
      target: target,
      combat_target_id: locked,
      map_name: state.game_state.map_name,
      timer: nil
    }

    %{state | step_action: step}
  end

  # The busy states `ensure_idle_for_cast/2` refuses, checked without changing
  # anything.
  defp cast_ready?(%{game_state: %{casting: casting}}, _opts) when not is_nil(casting),
    do: false

  defp cast_ready?(%{game_state: %{action_state: action_state}}, opts) do
    cond do
      action_state in [:idle, :moving, :combat_moving, :skill_moving, :moving_to_item, :attacking] ->
        true

      action_state in @overlaid_states ->
        Keyword.get(opts, :overlay?, false)

      true ->
        false
    end
  end

  @doc """
  Starts a cast a script asked for (rAthena `unitskilluseid`) on the player's own
  unit. The skill needs no learned rank; every other cast-begin and cast-end
  condition applies. A gate refusal leaves the state unchanged, an instant cast
  runs to its cast end here, and a timed one starts the ordinary cast bar.
  """
  @spec start_script_cast(SessionState.t(), integer(), pos_integer()) :: SessionState.t()
  def start_script_cast(state, skill_id, level) do
    with {:ok, gated} <- cast_gate(state, skill_id, :restricted),
         {:ok, ready} <- ensure_idle_for_cast(gated, overlay?: true) do
      result =
        Interpreter.begin_cast(
          stamp_cast_context(ready, ready.game_state),
          skill_id,
          level,
          :self,
          learned?: false,
          origin: :script
        )

      {:noreply, started} =
        handle_begin_result(ready, ready.game_state, skill_id, level, :self, nil, result)

      started
    else
      _refused -> state
    end
  end

  @doc """
  Schedules the next try of a remembered skill use half a step after the
  player entered a cell: half the time the walk's next step takes, or half a
  straight step at the end of the walk. A newer schedule replaces the last.
  """
  @spec schedule_step_action(SessionState.t(), non_neg_integer()) :: SessionState.t()
  def schedule_step_action(%{step_action: %{} = step} = state, half_step) do
    timer = make_ref()
    Process.send_after(self(), {:skill, {:step_action, timer}}, half_step)
    %{state | step_action: %{step | timer: timer}}
  end

  def schedule_step_action(state, _half_step), do: state

  @doc """
  Tries a remembered skill use again, as the source's step action does: the
  cast's own checks run without the client request stage, a target reached
  starts the cast, one still out of reach while walking stays remembered, and
  one out of range after the walk is dropped silently. A use remembered on
  another map, or replaced by a newer one, does nothing.
  """
  @spec handle_step_action(SessionState.t(), reference()) :: {:noreply, SessionState.t()}
  def handle_step_action(%{step_action: %{timer: timer} = step} = state, timer) do
    state = %{state | step_action: nil}

    with true <- step.map_name == state.game_state.map_name,
         {:ok, ready} <- cast_gate(state, step.skill_id, :request) do
      drive_cast_after_gate(
        ready,
        step.skill_id,
        step.level,
        step.target,
        step.combat_target_id,
        approach?: false
      )
    else
      _dropped -> {:noreply, state}
    end
  end

  def handle_step_action(state, _timer), do: {:noreply, state}

  defp reject_cast_gate(%{game_state: game_state} = state, skill_id, :busy) do
    report_cast_failure(skill_id, game_state.character_id, :busy)
    {:noreply, state}
  end

  defp reject_cast_gate(%{game_state: game_state} = state, _skill_id, _reason) do
    broadcast_cast_cancel(game_state)
    {:noreply, state}
  end

  # A pending item skill the request let through: the cast's own gate refuses
  # silently, then the cast starts as the request's kind allows.
  defp drive_item_cast(state, skill_id, level, target, opts \\ []) do
    with {:ok, state} <- cast_gate(state, skill_id, :item),
         {:ok, state} <- ensure_idle_for_cast(state, opts) do
      begin_ready_item_cast(state, skill_id, level, target)
    else
      {:error, _reason} -> {:noreply, state}
      :busy -> reject_cast_gate(state, skill_id, :busy)
    end
  end

  defp begin_ready_item_cast(state, skill_id, level, target) do
    game_state = state.game_state
    on_ready = &consume_pending_item(state, &1)
    keep? = Map.get(state.pending_item_skill, :keep_requirement?, false)

    game_state = stamp_cast_context(state, game_state)

    case Interpreter.begin_item_cast(game_state, skill_id, level, target, on_ready, keep?) do
      {:error, reason, refreshed, :before_start} ->
        handle_begin_result(
          state,
          game_state,
          skill_id,
          level,
          target,
          nil,
          {:error, reason, refreshed}
        )

      {:error, reason, refreshed, :after_start} ->
        handle_begin_result(
          forget_item_claim(state),
          game_state,
          skill_id,
          level,
          target,
          nil,
          {:error, reason, refreshed}
        )

      {:error, reason} ->
        handle_begin_result(
          state,
          game_state,
          skill_id,
          level,
          target,
          nil,
          {:error, reason}
        )

      result ->
        handle_begin_result(
          %{state | pending_item_skill: nil},
          game_state,
          skill_id,
          level,
          target,
          nil,
          result
        )
    end
  end

  # The item was claimed before the cast failed; its slot is empty now, as the
  # reference leaves `itemindex` at -1, so a repeated request fails silently.
  defp forget_item_claim(%{pending_item_skill: pending} = state) do
    %{state | pending_item_skill: Map.take(pending, [:skill_id, :level, :keep_requirement?])}
  end

  defp consume_pending_item(
         %{pending_item_skill: %{item_index: index, item_nameid: nameid}} = state,
         caster
       ) do
    case PlayerState.get_by_index(caster.inventory, index) do
      %{nameid: ^nameid, amount: amount} when amount > 0 ->
        claim_item(state, caster, index, nameid)

      _missing ->
        {:error, :missing_item}
    end
  end

  # The pending item skill has no claimable item: the reference's cast-begin item
  # branch fails it silently.
  defp consume_pending_item(_state, _caster), do: {:error, :missing_item}

  # A no-consume item is claimed for the cast and stays in the inventory (the
  # reference's DELAYCONSUME_NOCONSUME); every other claimed item is removed.
  defp claim_item(state, caster, index, nameid) do
    if no_consume_item?(nameid) do
      {:ok, caster}
    else
      with {:ok, inventory, _change} <-
             InventoryOps.remove(caster.character_id, caster.inventory, index, 1) do
        refreshed = %{caster | inventory: inventory}
        StateCommit.commit(state, refreshed)
        MessageRouter.send_to(state.connection_pid, InventoryView.item_removed(index, 1))
        PlayerEvents.inventory_changed(caster.character_id)
        {:ok, refreshed}
      end
    end
  end

  defp no_consume_item?(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %{no_consume: true}} -> true
      _not_found_or_consumed -> false
    end
  end

  # Every use that passed its cast-begin checks opens the logout window, whatever
  # its cast end does; a refused or approaching use does not.
  defp stamp_if_begun(state, {:error, _reason}), do: state
  defp stamp_if_begun(state, {:error, _reason, _refreshed}), do: state
  defp stamp_if_begun(state, _begun), do: Logout.stamp(state)

  defp handle_begin_result(state, game_state, skill_id, level, target, locked, result) do
    state = stamp_if_begun(state, result)

    case result do
      {:instant, new_game_state} ->
        sync_cast_start_stats(state, game_state, new_game_state)
        new_state = commit_cast(state, new_game_state, skill_id, level)
        # Keep the departure snapshot for this visual: commit_cast/5 may drain a
        # staged warp and move the player before the committed state returns.
        broadcast_skill_use(new_game_state, skill_id, level, target)
        maybe_replay_encore(new_state, skill_id)

      {:instant, new_game_state, effects} ->
        sync_cast_start_stats(state, game_state, new_game_state)

        new_state =
          state
          |> commit_cast(new_game_state, skill_id, level)
          |> settle_local_effects(effects)

        broadcast_skill_use(new_game_state, skill_id, level, target)
        maybe_replay_encore(new_state, skill_id)

      {:deferred, new_game_state, descriptor} ->
        sync_cast_start_stats(state, game_state, new_game_state)

        {:noreply, resolve_deferred(state, new_game_state, descriptor, homunculus_id(state))}

      {:casting, new_game_state, info} ->
        new_game_state = dispatch_committed_action(state, new_game_state, skill_id)
        sync_cast_start_stats(state, game_state, new_game_state)
        schedule_cast(%{state | game_state: new_game_state}, info)

      {:failed, new_game_state, reason} ->
        sync_cast_start_stats(state, game_state, new_game_state)
        {:noreply, commit_spent_failure(state, new_game_state, skill_id, level, target, reason)}

      {:castend_failed, new_game_state, reason} ->
        sync_cast_start_stats(state, game_state, new_game_state)
        {:noreply, commit_castend_failure(state, new_game_state, skill_id, level, reason)}

      error ->
        handle_begin_error(state, game_state, skill_id, level, target, locked, error)
    end
  end

  defp handle_begin_error(state, game_state, skill_id, level, target, locked, error) do
    case error do
      {:failed, new_game_state, reason, variant} ->
        sync_cast_start_stats(state, game_state, new_game_state)

        {:noreply,
         commit_variant_failure(variant, state, new_game_state, {skill_id, level, target}, reason)}

      {:skipped, new_game_state, _reason} ->
        sync_cast_start_stats(state, game_state, new_game_state)
        {:noreply, commit_skipped_use(state, new_game_state, skill_id, level)}

      {:error, :out_of_range, refreshed} ->
        committed = commit_failed_attempt(state, game_state, refreshed, skill_id, :out_of_range)
        approach(committed, skill_id, level, target, locked)

      {:error, reason, refreshed} ->
        {:noreply, commit_failed_attempt(state, game_state, refreshed, skill_id, reason)}

      {:error, :out_of_range} ->
        approach(state, skill_id, level, target, locked)

      {:error, reason} ->
        report_cast_failure(skill_id, game_state.character_id, reason)
        {:noreply, state}
    end
  end

  defp maybe_replay_encore(
         %{game_state: %{last_song: memory} = caster} = state,
         @encore_id
       )
       when is_map(memory) do
    result = Interpreter.begin_encore_replay(caster, memory, :self)
    handle_begin_result(state, caster, memory.skill_id, memory.level, :self, nil, result)
  end

  defp maybe_replay_encore(state, _skill_id), do: {:noreply, state}

  defp commit_failed_attempt(state, before, refreshed, skill_id, reason) do
    sync_cast_start_stats(state, before, refreshed)
    committed = StateCommit.commit(state, refreshed)

    if reason not in [:out_of_range, :step_action],
      do: report_cast_failure(skill_id, refreshed.character_id, reason)

    committed
  end

  # An instant cast's start effects ran inside the Interpreter; push any stat
  # change they made (Mystical Amplification arming, Cloaking ending) to the client.
  defp sync_cast_start_stats(state, before, after_cast) do
    if Stats.changed?(%{before.stats | current_state: nil}, %{
         after_cast.stats
         | current_state: nil
       }),
       do: StatusSync.send_stat_updates(state.connection_pid, after_cast.stats)

    if before.walk_speed != after_cast.walk_speed,
      do: StatusSync.send_param(state.connection_pid, StatusParams.speed(), after_cast.walk_speed)

    :ok
  end

  defp dispatch_committed_action(state, game_state, skill_id) do
    case StatusInterpreter.on_committed_action(
           :player,
           game_state.character_id,
           {:skill, skill_id}
         ) do
      :changed ->
        StatusManager.recalculate_after_status_change(%{state | game_state: game_state}).game_state

      :unchanged ->
        game_state
    end
  end

  @doc "Sets the Encore memory an ensemble partner receives from the caster's cast."
  @spec remember_song(SessionState.t(), integer(), pos_integer()) :: {:noreply, SessionState.t()}
  def remember_song(%{game_state: game_state} = state, skill_id, level) do
    {:noreply, StateCommit.commit(state, Snapshot.remember(game_state, skill_id, level))}
  end

  @doc "Returns and clears an unsettled deferred skill result."
  @spec take_deferred_skill_result(SessionState.t()) :: {map() | nil, SessionState.t()}
  def take_deferred_skill_result(state) do
    pending = Map.get(state, :deferred_skill_result)
    cancel_deferred_timer(pending)
    {pending, Map.replace(state, :deferred_skill_result, nil)}
  end

  @doc "Settles a matching Absorb Spirit Sphere reply against current caster state."
  @spec handle_spirit_absorb_result(
          SessionState.t(),
          reference(),
          non_neg_integer(),
          non_neg_integer()
        ) :: {:noreply, SessionState.t()}
  def handle_spirit_absorb_result(
        %{deferred_skill_result: %{token: token, target_id: target_id} = pending} = state,
        token,
        target_id,
        count
      ) do
    cancel_deferred_timer(pending)
    settle_absorb(%{state | deferred_skill_result: nil}, pending, count)
  end

  def handle_spirit_absorb_result(state, _token, _target_id, _count), do: {:noreply, state}

  # The SP was paid when the cast ended; the reply (or its absence) only decides
  # the reward, while the cooldown and act delay are armed either way.
  defp settle_absorb(state, pending, count) do
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

        {:noreply, new_state}

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  @doc """
  Closes a matching deferred skill after its one-second reply window as if the
  target held no spheres: no reward, but the cooldown and act delay still arm.
  """
  @spec handle_deferred_timeout(SessionState.t(), reference()) :: {:noreply, SessionState.t()}
  def handle_deferred_timeout(
        %{deferred_skill_result: %{token: token} = pending} = state,
        token
      ) do
    settle_absorb(%{state | deferred_skill_result: nil}, pending, 0)
  end

  def handle_deferred_timeout(state, _token), do: {:noreply, state}

  @doc "Cancels a pending deferred skill without charging or resuming combat."
  @spec cancel_deferred(SessionState.t()) :: SessionState.t()
  def cancel_deferred(state) do
    {_pending, state} = take_deferred_skill_result(state)
    state
  end

  defp resolve_deferred(state, game_state, descriptor),
    do: resolve_deferred(state, game_state, descriptor, nil)

  defp resolve_deferred(
         state,
         game_state,
         %Interpreter.Deferred{
           effect: {:potion_delivery, target_ref, potion_descriptor}
         } = descriptor,
         _expected_id
       ),
       do: resolve_potion(state, game_state, descriptor, target_ref, potion_descriptor, [])

  defp resolve_deferred(
         state,
         game_state,
         %Interpreter.Deferred{
           effect: {:potion_delivery, target_ref, potion_descriptor, thrower_damages}
         } = descriptor,
         _expected_id
       ),
       do:
         resolve_potion(
           state,
           game_state,
           descriptor,
           target_ref,
           potion_descriptor,
           thrower_damages
         )

  defp resolve_deferred(
         state,
         game_state,
         %Interpreter.Deferred{effect: {:homunculus_lifecycle, _operation}} = descriptor,
         expected_id
       ) do
    case settle_lifecycle_deferred(state, game_state, descriptor, expected_id) do
      {:ok, settled, item_change} ->
        notify_lifecycle_item(settled.connection_pid, item_change)
        settled = send_homunculus_private_state(settled)

        broadcast_skill_use(
          settled.game_state,
          descriptor.skill_id,
          descriptor.level,
          descriptor.target
        )

        settled

      {:error, reason, unchanged} ->
        Logger.error("Homunculus lifecycle skill settlement failed: #{inspect(reason)}")
        report_cast_failure(descriptor.skill_id, game_state.character_id, reason)
        unchanged
    end
  end

  defp resolve_deferred(
         state,
         game_state,
         %Interpreter.Deferred{effect: {:absorb_local, reward}} = descriptor,
         _expected_id
       ) do
    case Interpreter.settle_deferred(game_state, descriptor) do
      {:ok, charged} ->
        rewarded = restore_sp(charged, reward)
        new_state = commit_cast(state, rewarded, descriptor.skill_id, descriptor.level)
        broadcast_skill_use(rewarded, descriptor.skill_id, descriptor.level, descriptor.target)
        new_state

      {:error, _reason} ->
        %{state | game_state: game_state}
    end
  end

  defp resolve_deferred(
         state,
         game_state,
         %Interpreter.Deferred{effect: {:transfer_sphere, target_id}} = descriptor,
         _expected_id
       ) do
    case Interpreter.settle_deferred(game_state, descriptor) do
      {:ok, charged} ->
        new_state = commit_cast(state, charged, descriptor.skill_id, descriptor.level)
        broadcast_skill_use(charged, descriptor.skill_id, descriptor.level, descriptor.target)
        SpiritExchangeHandler.transfer(new_state, target_id)
        new_state

      {:error, _reason} ->
        %{state | game_state: game_state}
    end
  end

  defp resolve_deferred(
         state,
         game_state,
         %Interpreter.Deferred{effect: {:absorb_player, target_id}} = descriptor,
         _expected_id
       ) do
    token = make_ref()
    timer_ref = Process.send_after(self(), {:deferred_skill_timeout, token}, 1_000)

    state = %{
      state
      | game_state: game_state,
        deferred_skill_result: %{
          descriptor: descriptor,
          target_id: target_id,
          token: token,
          timer_ref: timer_ref
        }
    }

    SpiritExchangeHandler.request_absorb(state, target_id, token)
    state
  end

  defp resolve_deferred(state, game_state, _descriptor, _expected_id),
    do: %{state | game_state: game_state}

  @doc "Executes and settles an instant owner lifecycle skill inside the current session."
  @spec execute_lifecycle_skill(SessionState.t(), integer(), pos_integer()) ::
          {:ok, SessionState.t()} | {:error, term(), SessionState.t()}
  def execute_lifecycle_skill(%SessionState{} = state, skill_id, level) do
    expected_id = homunculus_id(state)

    with :ok <- ensure_no_deferred_skill(state),
         {:ok, gated_state} <- cast_gate(state, skill_id),
         {:ok, ready_state} <- ensure_idle_for_cast(gated_state, notify?: false),
         {:deferred, game_state, %Interpreter.Deferred{} = descriptor} <-
           Interpreter.cast(
             stamp_cast_context(ready_state, ready_state.game_state),
             skill_id,
             level,
             :self
           ),
         {:ok, settled, item_change} <-
           settle_lifecycle_deferred(ready_state, game_state, descriptor, expected_id) do
      cancel_staged_action_timer(state)
      MovementHandler.publish_force_stop_movement(state)
      notify_lifecycle_item(settled.connection_pid, item_change)

      broadcast_skill_use(
        settled.game_state,
        descriptor.skill_id,
        descriptor.level,
        descriptor.target
      )

      {:ok, settled}
    else
      :busy ->
        {:error, :busy, state}

      {:error, reason, refreshed} ->
        {:error, reason, StateCommit.commit(state, refreshed)}

      {:error, reason} ->
        {:error, reason, state}

      _unexpected ->
        {:error, :invalid_lifecycle_skill, state}
    end
  end

  defp ensure_no_deferred_skill(%{deferred_skill_result: nil}), do: :ok
  defp ensure_no_deferred_skill(_state), do: {:error, :busy}

  defp cancel_staged_action_timer(%{game_state: %{continuous_attack_timer: timer_ref}})
       when is_reference(timer_ref) do
    Process.cancel_timer(timer_ref)
    :ok
  end

  defp cancel_staged_action_timer(_state), do: :ok

  defp settle_lifecycle_deferred(
         state,
         game_state,
         %Interpreter.Deferred{effect: {:homunculus_lifecycle, operation}} = descriptor,
         expected_id
       ) do
    case Interpreter.settle_deferred(game_state, descriptor) do
      {:ok, charged} ->
        settle_charged_lifecycle(state, charged, descriptor, operation, expected_id)

      {:error, reason} ->
        {:error, reason, %{state | game_state: game_state}}
    end
  end

  defp settle_charged_lifecycle(state, charged, descriptor, operation, expected_id) do
    case LifecycleSkillHandler.settle(state, charged, operation, expected_id) do
      {:ok, settled, homunculus, runtime, item_change, activation_gid} ->
        {state, sphere_cost_plan} = prepare_cast_commit(state, settled)
        state = %{state | homunculus_runtime: runtime}
        state = commit_homunculus_transition(state, operation, homunculus, activation_gid)

        committed =
          publish_cast_commit(
            state,
            descriptor.skill_id,
            descriptor.level,
            true,
            sphere_cost_plan
          )

        {:ok, committed, item_change}

      # The reference arms the cast's cooldown and its after-cast delay at the
      # cast end, before the effect that fails here, so only the failed
      # lifecycle mutation is dropped.
      {:error, reason} ->
        {:error, reason, %{state | game_state: charged}}
    end
  end

  defp settle_potion_inventory(
         %PlayerState{
           character_id: character_id,
           pending_inventory_persist: [{old_inventory, new_inventory, change}]
         } = game_state
       ) do
    case InventoryOps.apply_change(character_id, old_inventory, new_inventory, change) do
      {:ok, persisted_inventory} ->
        {:ok,
         %{
           game_state
           | inventory: persisted_inventory,
             pending_inventory_persist: []
         }}

      {:error, reason} ->
        {:error, {:inventory_persistence_failed, reason}}
    end
  end

  defp settle_potion_inventory(%PlayerState{}), do: {:error, :invalid_potion_staging}

  defp settle_local_effects(state, effects) do
    effects
    |> Enum.reduce(state, fn effect, current ->
      {:noreply, updated} = HomunculusCommandHandler.local_effect(effect, current)
      updated
    end)
    |> HomunculusCommandHandler.publish_private_state_if_dirty()
  end

  defp resolve_potion(
         state,
         game_state,
         descriptor,
         target_ref,
         potion_descriptor,
         thrower_damages
       ) do
    with {:ok, charged} <- Interpreter.settle_deferred(game_state, descriptor),
         {:ok, settled} <- settle_potion_inventory(charged) do
      committed = commit_cast(state, settled, descriptor.skill_id, descriptor.level)
      broadcast_skill_use(settled, descriptor.skill_id, descriptor.level, descriptor.target)

      committed
      |> deliver_potion(target_ref, potion_descriptor)
      |> settle_thrower_damages(thrower_damages)
    else
      {:error, reason} ->
        Logger.error("Potion Pitcher settlement failed: #{inspect(reason)}")
        report_cast_failure(descriptor.skill_id, game_state.character_id, reason)
        state
    end
  end

  defp settle_thrower_damages(state, damages) do
    Enum.reduce(damages, state, fn damage, acc ->
      {:noreply, settled} = HealthHandler.settle_script_damage(damage, acc)
      settled
    end)
  end

  defp deliver_potion(state, {:player, target_id}, descriptor) do
    DamageApplication.apply_heal(
      :player,
      target_id,
      descriptor,
      state.game_state.character_id
    )

    state
  end

  defp deliver_potion(
         %{game_state: %{character_id: owner_id}} = state,
         {:homunculus, gid} = target_ref,
         descriptor
       ) do
    case UnitRegistry.get_unit(:homunculus, gid) do
      {:ok, {HomunculusState, %HomunculusState{owner_character_id: ^owner_id}, owner_pid}}
      when owner_pid == self() ->
        source = {:player, state.game_state.character_id}
        effect = DamageApplication.local_heal_effect(target_ref, descriptor, source)
        {:noreply, delivered} = HomunculusCommandHandler.local_effect(effect, state)
        HomunculusCommandHandler.publish_private_state_if_dirty(delivered)

      _stale ->
        state
    end
  end

  defp commit_homunculus_transition(state, :rest, homunculus, nil) do
    state
    |> HomunculusStateCommit.commit(homunculus)
    |> HomunculusCommandHandler.deactivate_runtime()
  end

  defp commit_homunculus_transition(state, _operation, homunculus, activation_gid) do
    state
    |> HomunculusStateCommit.activate_claimed(homunculus, activation_gid)
    |> HomunculusCommandHandler.arm_active_runtime()
  end

  defp notify_lifecycle_item(_connection_pid, nil), do: :ok

  defp notify_lifecycle_item(connection_pid, {:removed, index}),
    do: MessageRouter.send_to(connection_pid, InventoryView.item_removed(index, 1))

  defp notify_lifecycle_item(connection_pid, {:reduced, index, _left}),
    do: MessageRouter.send_to(connection_pid, InventoryView.item_removed(index, 1))

  defp send_homunculus_private_state(%{homunculus: nil} = state), do: state

  defp send_homunculus_private_state(state) do
    packet = PrivateStateView.build(state.homunculus, state.homunculus_runtime)
    MessageRouter.send_to(state.connection_pid, packet)
    %{state | homunculus_runtime: %{state.homunculus_runtime | private_dirty: false}}
  end

  defp homunculus_id(%{homunculus: nil}), do: nil
  defp homunculus_id(%{homunculus: homunculus}), do: homunculus.id

  defp lifecycle_homunculus_id(state, skill_id, level) do
    if LifecycleSkillHandler.operation(skill_id, level), do: homunculus_id(state)
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
  Ends the walk toward a skill target: the player stands idle. The remembered
  use (`step_action`) is tried one last time half a step after the last cell.
  """
  @spec handle_reached_skill_position(SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_reached_skill_position(%{game_state: game_state} = state) do
    {:noreply, %{state | game_state: to_idle(game_state)}}
  end

  # A standing player's request out of range is walked into range on the
  # client's behalf. An item skill is not: its item was spent when the cast
  # began, and a remembered item use would only fail when tried again, so it
  # ends here without a reply.
  defp approach(state, skill_id, level, target, locked) do
    if match?(%{skill_id: ^skill_id}, Map.get(state, :pending_item_skill)),
      do: {:noreply, state},
      else: initiate_skill_movement(state, skill_id, level, target, locked)
  end

  # Walks the caster toward a target out of range, standing in for the client
  # that walks before it asks, and remembers the use so each step tries it
  # again. Nothing happens, and nothing is said, when the target is gone, no
  # closer cell exists or no path reaches it.
  defp initiate_skill_movement(%{game_state: game_state} = state, skill_id, level, target, locked) do
    with :ok <- ensure_living_target(target),
         {:ok, target_pos} <- skill_target_position(target),
         {:ok, definition} <- Catalog.by_id(skill_id),
         {:ok, map_data} <- MapCache.get(game_state.map_name) do
      range = Interpreter.effective_range(definition, game_state, level)
      current = {game_state.x, game_state.y}
      optimal = CombatActionHandler.get_optimal_attack_position(current, target_pos, range)

      move_toward_skill_target(state, skill_id, level, target, current, optimal, map_data, locked)
    else
      _ -> {:noreply, state}
    end
  end

  # Optimal cell equals the current cell: no closer approach exists.
  defp move_toward_skill_target(
         state,
         _skill_id,
         _level,
         _target,
         current,
         current,
         _map_data,
         _locked
       ),
       do: {:noreply, state}

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
    case Pathfinding.rewalk_path(map_data, current, optimal) do
      {:ok, [_ | _]} ->
        start_skill_approach(state, skill_id, level, target, optimal, locked)

      _no_path ->
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
    context = %{skill_id: skill_id, skill_level: level, target: target}

    case PlayerState.transition_to(stop_attack_for_walk(game_state), :skill_moving, context) do
      {:ok, moving_state} ->
        %{state | game_state: moving_state}
        |> remember_step(skill_id, level, target, locked)
        |> MovementHandler.handle_request_move(x, y, skill_initiated: true)

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  # A walk begins by ending the attack.
  defp stop_attack_for_walk(%PlayerState{action_state: :attacking} = game_state),
    do: to_idle(game_state)

  defp stop_attack_for_walk(game_state), do: game_state

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

  # A dead player stays a legal approach target: the reference walks to it and
  # the cast end then ends without its effect. A dead monster is off the map.
  defp ensure_living_target({:unit, unit_id}) do
    case TargetResolver.resolve(unit_id) do
      {:ok, _pid, _target_state, :player} ->
        :ok

      {:ok, _pid, target_state, unit_type} ->
        TargetResolver.ensure_targetable(target_state, unit_type)

      {:error, _reason} ->
        :ok
    end
  end

  defp ensure_living_target(_target), do: :ok

  @doc """
  Applies the session-owned living, status, and action gate for a skill cast.

  Staged and resumed input casts use the default start phase. A player's
  request that `SkillRequest` let through uses `:request`, or `:item` for a
  pending item skill, which casting locks and skill blocks do not stop; the
  request already settled the action checks, so neither repeats them.
  Timed casts use `:completion`, which requires the existing cast action to still
  be active and leaves the caster's statuses to the interpreter's completion
  check: a status that only forbids starting a cast does not stop one already
  under way.
  """
  @spec cast_gate(
          SessionState.t(),
          integer(),
          :start | :request | :item | :completion | :restricted
        ) ::
          {:ok, SessionState.t()} | {:error, :dead | :status_blocked | :menu_open | :busy}
  def cast_gate(state, skill_id, phase \\ :start)

  def cast_gate(%{game_state: game_state} = state, skill_id, phase) do
    with :ok <- ensure_living_caster(game_state),
         :ok <- check_start_status(game_state, skill_id, phase),
         :ok <- check_open_menu(state, skill_id, phase) do
      check_cast_action(state, phase)
    end
  end

  # While Pharmacy's production list is open, the production skills that would
  # open another list are refused at cast begin and cast end, without a message,
  # an item's cast included.
  defp check_open_menu(state, skill_id, _phase) when skill_id in @pharmacy_menu_refused do
    case Map.get(state, :pending_skill_menu) do
      %{skill_id: @pharmacy} -> {:error, :menu_open}
      _other -> :ok
    end
  end

  defp check_open_menu(_state, _skill_id, _phase), do: :ok

  defp check_start_status(_game_state, _skill_id, :completion), do: :ok

  defp check_start_status(game_state, skill_id, phase) do
    if start_allowed?(game_state.character_id, skill_id, phase),
      do: :ok,
      else: {:error, :status_blocked}
  end

  defp start_allowed?(id, skill_id, :item),
    do: StatusInterpreter.can_use_skill?(:player, id, skill_id, true)

  defp start_allowed?(id, skill_id, _phase),
    do: StatusInterpreter.can_use_skill?(:player, id, skill_id)

  defp ensure_living_caster(%{action_state: :dead}), do: {:error, :dead}

  defp ensure_living_caster(%{stats: %{current_state: %{hp: hp}}}) when hp <= 0,
    do: {:error, :dead}

  defp ensure_living_caster(_game_state), do: :ok

  defp check_cast_action(state, phase) when phase in [:request, :item], do: {:ok, state}

  defp check_cast_action(state, :start) do
    if SessionState.interaction_blocked?(state) or
         match?(%{kind: :OPTIONS}, Map.get(state, :pending_skill_menu)) do
      {:error, :busy}
    else
      check_start_action(state)
    end
  end

  defp check_cast_action(%{game_state: %{casting: casting}} = state, :completion)
       when not is_nil(casting),
       do: {:ok, state}

  defp check_cast_action(_state, :completion), do: {:error, :busy}
  defp check_cast_action(state, :restricted), do: {:ok, state}

  defp check_start_action(%{game_state: %{casting: casting}})
       when not is_nil(casting),
       do: {:error, :busy}

  defp check_start_action(%{game_state: %{action_state: action_state}} = state)
       when action_state in [
              :idle,
              :attacking,
              :moving,
              :combat_moving,
              :skill_moving,
              :moving_to_item
            ],
       do: {:ok, state}

  defp check_start_action(_state), do: {:error, :busy}

  # Once the read-only gate and cast validation permit dispatch, prepare the
  # ordinary cast action. A moving player is stopped first; any other busy state
  # aborts. An in-flight descriptor rejects regardless of action_state.
  defp ensure_idle_for_cast(state, opts \\ [])

  defp ensure_idle_for_cast(%{game_state: %{casting: casting}}, _opts)
       when not is_nil(casting),
       do: :busy

  defp ensure_idle_for_cast(%{game_state: %{action_state: :idle}} = state, _opts),
    do: {:ok, state}

  defp ensure_idle_for_cast(%{game_state: %{action_state: moving}} = state, opts)
       when moving in [:moving, :combat_moving, :skill_moving, :moving_to_item] do
    stopped_state = stop_movement_for_cast(state, Keyword.get(opts, :notify?, true))
    transition_to_cast_idle(stopped_state, opts)
  end

  # A player mid-swing in the auto-attack loop sits in :attacking between swings.
  # Casting from there is legal. The cast's begin ends the attack once its checks
  # pass (`Interpreter`), so a refused cast leaves the attack running.
  defp ensure_idle_for_cast(%{game_state: %{action_state: :attacking}} = state, _opts),
    do: {:ok, state}

  # A script cast starts over a sitting or trading player and leaves that state
  # as it is.
  defp ensure_idle_for_cast(%{game_state: %{action_state: held}} = state, opts)
       when held in @overlaid_states do
    if Keyword.get(opts, :overlay?, false), do: {:ok, state}, else: :busy
  end

  defp ensure_idle_for_cast(_state, _opts), do: :busy

  defp stop_movement_for_cast(state, true) do
    {:noreply, stopped_state} = MovementHandler.handle_force_stop_movement(state)
    stopped_state
  end

  defp stop_movement_for_cast(%{game_state: game_state} = state, false),
    do: %{state | game_state: PlayerState.stop_walking(game_state)}

  defp transition_to_cast_idle(%{game_state: game_state} = state, opts) do
    game_state =
      if Keyword.get(opts, :notify?, true),
        do: game_state,
        else: %{game_state | continuous_attack_timer: nil}

    case PlayerState.transition_to(game_state, :idle) do
      {:ok, idle_game_state} -> {:ok, %{state | game_state: idle_game_state}}
      {:error, _reason} -> :busy
    end
  end

  defp cast_cancel?(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, definition} -> definition.cast_cancel
      :error -> true
    end
  end

  # Arrow Vulcan holds equipment changes for the rest of its cast.
  defp lock_equip_change(state, %{skill_id: @arrow_vulcan_id, total: total}, now)
       when total > 0,
       do: %{state | equip_lock_until: now + total}

  defp lock_equip_change(state, _info, _now), do: state

  defp schedule_cast(%{game_state: game_state} = state, info) do
    now = System.monotonic_time(:millisecond)
    state = lock_equip_change(state, info, now)
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
      interruptible: cast_cancel?(info.skill_id),
      homunculus_id: lifecycle_homunculus_id(state, info.skill_id, info.level),
      origin: Map.get(info, :origin, :normal),
      memory: Map.get(info, :memory),
      keep_requirement?: Map.get(info, :keep_requirement?, false)
    }

    case start_casting(game_state, context) do
      {:ok, casting_state} ->
        broadcast_cast_bar(casting_state, info)
        {:noreply, StateCommit.commit(state, casting_state)}

      {:error, reason} ->
        Process.cancel_timer(timer_ref)
        report_cast_failure(info.skill_id, game_state.character_id, reason)
        {:noreply, StateCommit.commit(state, game_state)}
    end
  end

  defp start_casting(%{action_state: held} = game_state, context)
       when held in @overlaid_states,
       do: {:ok, %{game_state | casting: context}}

  defp start_casting(game_state, context),
    do: PlayerState.transition_to(game_state, :casting, context)

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
  # clear the combat intent the loop runs on. A timed combo kept its attack: a
  # swing still pending carries on after it.
  defp end_cast(
         %{action_state: :casting, combat_target_id: target_id, continuous_attack_timer: timer} =
           game_state
       )
       when not is_nil(target_id) and not is_nil(timer) do
    {:ok, attacking} = PlayerState.transition_to(game_state, :attacking)
    PlayerState.clear_casting(attacking)
  end

  defp end_cast(%{action_state: :casting} = game_state) do
    game_state |> to_idle() |> PlayerState.clear_casting()
  end

  defp end_cast(game_state), do: PlayerState.clear_casting(game_state)

  # Shared success path: calculate the final player state, commit it to the
  # registry, then perform every outward effect. The committed state is the gate
  # for persistence, packets, timer work, and staged follow-up actions.
  # `postdelay?` is false for the auto-cast path only: the SkillCooldown packet
  # announces the cooldown the interpreter just wrote, and `auto_cast/4` writes
  # none, so sending it would grey out a bolt the server still considers ready.
  defp commit_cast(state, new_game_state, skill_id, level, postdelay? \\ true) do
    {state, sphere_cost_plan} = prepare_cast_commit(state, new_game_state)
    publish_cast_commit(state, skill_id, level, postdelay?, sphere_cost_plan)
  end

  defp prepare_cast_commit(%{connection_pid: connection_pid} = state, new_game_state) do
    new_game_state = stamp_vending_cost(state.game_state, new_game_state)
    previous_spheres = state.game_state.spirit_spheres
    equipped = Map.values(Inventory.equipped_items(new_game_state.inventory))

    updated_stats =
      Calculator.calculate_stats(new_game_state.stats, new_game_state.character_id, equipped)

    walk_speed = StatusManager.walk_speed_for(updated_stats)

    if walk_speed != state.game_state.walk_speed,
      do: StatusSync.send_param(connection_pid, StatusParams.speed(), walk_speed)

    new_game_state = %{new_game_state | stats: updated_stats, walk_speed: walk_speed}

    {new_game_state, sphere_cost_plan} =
      SpiritSphereHandler.prepare_skill_cost(new_game_state, previous_spheres)

    state = StateCommit.commit(state, new_game_state)

    state =
      update_in(state.game_state, fn game_state ->
        InventoryStaging.drain(connection_pid, game_state)
      end)

    {state, sphere_cost_plan}
  end

  defp publish_cast_commit(state, skill_id, level, postdelay?, sphere_cost_plan) do
    %{connection_pid: connection_pid, game_state: game_state} = state

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
    |> drain_hp_loss()
    |> drain_production_result()
    |> drain_forced_movement(skill_id)
    |> drain_warp()
    |> drain_interaction()
    |> drain_menu_offer()
    |> drain_vending_setup()
  end

  # A failed Create Deadly Poison's passive HP loss: it can kill, cancels no cast
  # and is applied before the production result is sent.
  defp drain_hp_loss(%{game_state: %{pending_hp_loss: nil}} = state), do: state

  defp drain_hp_loss(%{game_state: %{pending_hp_loss: loss} = game_state} = state) do
    state = %{state | game_state: %{game_state | pending_hp_loss: nil}}
    {:noreply, state} = HealthHandler.apply_script_vitals({:heal, -loss, 0}, state)
    state
  end

  defp drain_production_result(%{connection_pid: connection_pid, game_state: game_state} = state),
    do: %{
      state
      | game_state: SkillMenuHandler.drain_production_result(connection_pid, game_state)
    }

  @doc false
  @spec drain_forced_movement(map(), integer()) :: map()
  defp drain_forced_movement(%{game_state: game_state} = state, skill_id) do
    {directive, clean_game_state} = PlayerState.take_pending_forced_movement(game_state)

    case directive do
      nil ->
        %{state | game_state: clean_game_state}

      %ForcedMovement{map_name: map_name, x: x, y: y} ->
        moved_state =
          clean_game_state
          |> PlayerState.update_position(x, y)
          |> PlayerState.stop_walking()

        :ok = Movement.set_position(:player, moved_state.character_id, moved_state, map_name)

        blocked_cooldowns =
          if skill_id == 264 do
            blocked_until =
              max(
                Map.get(moved_state.skill_cooldowns, 271, 0),
                System.monotonic_time(:millisecond) + 2_000
              )

            Cooldown.put(
              moved_state.skill_cooldowns,
              271,
              blocked_until
            )
          else
            moved_state.skill_cooldowns
          end

        %{state | game_state: %{moved_state | skill_cooldowns: blocked_cooldowns}}
    end
  end

  defp stamp_vending_cost(previous, %{pending_vending_setup: offer} = current)
       when is_map(offer) do
    spent = max(previous.stats.current_state.sp - current.stats.current_state.sp, 0)
    %{current | pending_vending_setup: Map.put(offer, :sp_spent, spent)}
  end

  defp stamp_vending_cost(_previous, current), do: current

  defp drain_vending_setup(%{game_state: %{pending_vending_setup: nil}} = state), do: state

  defp drain_vending_setup(%{game_state: game_state} = state) do
    offer = game_state.pending_vending_setup
    state = %{state | game_state: %{game_state | pending_vending_setup: nil}}

    case VendingHandler.prepare_setup(state, offer) do
      {:ok, prepared} ->
        prepared

      {:error, reason} ->
        report_cast_failure(41, game_state.character_id, reason)
        state
    end
  end

  # Sends the SkillMenu a cast staged on pending_menu_offer (SA_AUTOSPELL's bolt
  # list) and parks it on the session. Drained after the cast commits, so the SP
  # is already spent by the time the client can answer - and a reply that never
  # comes simply leaves the offer to be cleared by death, warp or disconnect.
  defp drain_menu_offer(%{game_state: %{pending_menu_offer: nil}} = state), do: state

  defp drain_menu_offer(%{game_state: game_state} = state) do
    %{skill_id: skill_id, kind: kind, entry_ids: entry_ids, level: level} =
      offer =
      game_state.pending_menu_offer

    opts = offer |> Map.take([:labels, :context]) |> Map.to_list()

    %{state | game_state: %{game_state | pending_menu_offer: nil}}
    |> SkillMenuHandler.open(skill_id, kind, entry_ids, level, opts)
  end

  @doc """
  Runs a bolt SA_AUTOSPELL's proc armed, cast to this session by the combat path
  once the triggering weapon hit committed.

  The restricted interpreter entry does the mechanics (2/3 SP, no cast time, no
  catalyst, aftercast delay); this commits the result the way a real cast does, so
  the drained SP is persisted and synced. A proc without the SP leaves the
  session untouched and tells the player nothing; one whose effect fails after
  the SP was charged commits the charge and its delay just as silently.
  """
  @spec handle_auto_cast(SessionState.t(), integer(), pos_integer(), Active.target()) ::
          {:noreply, SessionState.t()}
  def handle_auto_cast(%{game_state: game_state} = state, skill_id, level, target) do
    case Interpreter.auto_cast(stamp_cast_context(state, game_state), skill_id, level, target) do
      {:ok, new_game_state} ->
        new_state = commit_cast(state, new_game_state, skill_id, level, false)
        broadcast_skill_use(new_state.game_state, skill_id, level, target)
        {:noreply, new_state}

      {:failed, new_game_state, reason} ->
        {:noreply, close_failed_auto_use(state, new_game_state, skill_id, level, target, reason)}

      {:error, _reason, charged} ->
        {:noreply, commit_cast(state, charged, skill_id, level, false)}

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  # An automatic use whose effect failed after its requirement was spent: the
  # spend commits, the caster sees the failure and the use still closes.
  defp close_failed_auto_use(state, new_game_state, skill_id, level, target, reason) do
    new_state = commit_cast(state, new_game_state, skill_id, level, false)
    report_cast_failure(skill_id, new_state.game_state.character_id, reason)
    CastEnd.complete(new_state.game_state, skill_id, target)
    new_state
  end

  @doc """
  Runs an equipment-granted proc cast for this player.

  The equipment sibling of `handle_auto_cast/4`: it routes to the interpreter's
  proc entry, which consumes the skill's requirement with the SP waived and
  never arms its cooldown. The map and cooldown restrictions are checked first
  (`Interpreter.check_proc_usable/3`) and a refusal sends its reply; a proc
  refused by the interpreter is dropped silently; an effect that fails after
  the requirement was spent commits the
  spent resources just as silently. A requirement that took the player's last
  HP kills them. A completed proc arms the player's on-skill procs like any
  other skill use.
  """
  @spec handle_proc_cast(map(), integer(), pos_integer(), term()) :: {:noreply, map()}
  def handle_proc_cast(%{game_state: game_state} = state, skill_id, level, target) do
    case Interpreter.check_proc_usable(game_state, skill_id, Map.get(state, :pending_item_skill)) do
      :ok ->
        cast_usable_proc(state, skill_id, level, target)

      {:error, {:not_ok, _reply} = reason} ->
        report_cast_failure(skill_id, game_state.character_id, reason)
        {:noreply, state}

      {:error, _unknown_skill} ->
        {:noreply, state}
    end
  end

  defp cast_usable_proc(state, skill_id, level, target) do
    result =
      Interpreter.proc_cast(stamp_cast_context(state, state.game_state), skill_id, level, target)

    run_proc_cast(state, skill_id, level, target, result)
  end

  @doc """
  Resolves one equipment proc selected for this player by a hit or a skill use.

  The usability check and the level and chance draws run here, in the wearer's
  own session, in the order of the proc's branch (`EquipAutocast.resolve/2`). A
  proc refused by the map and cooldown restrictions sends that refusal's reply
  before any roll, as an ordinary skill use would. An on-skill
  proc arms no after-cast delay and, while it executes, cannot re-trigger the
  entry that cast it.
  """
  @spec handle_equip_proc(SessionState.t(), EquipAutocast.candidate()) ::
          {:noreply, SessionState.t()}
  def handle_equip_proc(%{game_state: game_state} = state, candidate) do
    usable = &Interpreter.check_proc_usable(game_state, &1, Map.get(state, :pending_item_skill))

    case EquipAutocast.resolve(candidate, usable: usable) do
      {:cast, level} ->
        run_equip_proc(state, candidate, level)

      {:unusable, {:not_ok, _reply} = reason} ->
        report_cast_failure(candidate.skill_id, game_state.character_id, reason)
        {:noreply, state}

      _skipped ->
        {:noreply, state}
    end
  end

  defp run_equip_proc(state, %{branch: :skill} = candidate, level) do
    %{skill_id: skill_id, target: target, entry: entry} = candidate
    entry = EquipAutocast.current_identity(state.game_state.stats.modifiers.equipment, entry)
    {_trigger, _index, %{trigger_skill: trigger_skill}} = entry
    opts = [act_delay?: false, placement_skill: trigger_skill]

    EquipProcDispatch.with_on_skill_lock(state.game_state.character_id, entry, fn ->
      result =
        Interpreter.proc_cast(
          stamp_cast_context(state, state.game_state),
          skill_id,
          level,
          target,
          opts
        )

      run_proc_cast(state, skill_id, level, target, result)
    end)
  end

  defp run_equip_proc(state, candidate, level),
    do: cast_usable_proc(state, candidate.skill_id, level, candidate.target)

  defp run_proc_cast(state, skill_id, level, target, result) do
    case result do
      {:ok, new_game_state} ->
        new_state = commit_cast(state, new_game_state, skill_id, level, false)
        broadcast_skill_use(new_state.game_state, skill_id, level, target)
        HealthHandler.settle_lethal_cost(new_state)

      {:failed, new_game_state, reason} ->
        state
        |> close_failed_auto_use(new_game_state, skill_id, level, target, reason)
        |> HealthHandler.settle_lethal_cost()

      {:error, _reason, charged} ->
        HealthHandler.settle_lethal_cost(commit_cast(state, charged, skill_id, level, false))

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  # Starts the Script.Interaction a skill staged on pending_interaction (the
  # same lock-and-monitor wiring as NpcInteractionHandler.talk_to_npc). Dropped
  # when a dialog is already active, mirroring the NPC-click guard.
  defp drain_interaction(%{game_state: %{pending_interaction: nil}} = state), do: state

  defp drain_interaction(%{game_state: game_state} = state) do
    if SessionState.interaction_blocked?(state) do
      %{state | game_state: %{game_state | pending_interaction: nil}}
    else
      start_pending_interaction(state, game_state)
    end
  end

  defp start_pending_interaction(state, game_state) do
    module = game_state.pending_interaction
    clean_game_state = %{game_state | pending_interaction: nil}

    base_ctx =
      Ctx.from_session(
        %{game_state: clean_game_state, connection_pid: state.connection_pid},
        {:npc, module}
      )

    gid = SessionState.system_dialog_gid()
    base_ctx = %{base_ctx | npc_gid: gid}
    {:ok, pid} = Interaction.start(self(), module, base_ctx)
    ref = Process.monitor(pid)

    %{state | game_state: clean_game_state, interaction_lock: {pid, ref, gid}}
  end

  @doc """
  Executes and clears a warp directive staged by a successful skill effect.

  The directive is cleared before calling `WarpHandler` and remains cleared
  when the destination is invalid, preventing a later cast from retrying it.
  """
  @spec drain_warp(map()) :: map()
  def drain_warp(%{game_state: game_state} = state) do
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

  @doc "Turns the player's act delay and cooldown refusal notices on or off."
  @spec toggle_show_delay(SessionState.t()) :: SessionState.t()
  def toggle_show_delay(%{game_state: game_state} = state),
    do: StateCommit.commit(state, %{game_state | show_delay: not game_state.show_delay})

  @doc false
  @spec report_cast_failure(integer(), non_neg_integer(), term()) :: :ok
  def report_cast_failure(_skill_id, _character_id, {:not_ok, :silent}), do: :ok

  def report_cast_failure(skill_id, character_id, {:not_ok, {:fail, reason}}),
    do: report_cast_failure(skill_id, character_id, reason)

  def report_cast_failure(skill_id, character_id, {:not_ok, {:message, text, reply}}) do
    Broadcast.to_player(character_id, %ChatMessage{gid: character_id, message: text})
    report_cast_failure(skill_id, character_id, {:not_ok, reply})
  end

  def report_cast_failure(_skill_id, character_id, {:not_ok, {:notice, id}}) do
    Broadcast.to_player(character_id, %SystemNotice{id: id})
    :ok
  end

  def report_cast_failure(skill_id, character_id, reason)
      when reason in [
             :target_concealed,
             :target_restricted,
             :caster_restricted,
             :guild_skill_unavailable,
             :target_not_found,
             :different_map,
             :no_target_self,
             :status_blocked,
             :in_chat_room,
             :missing_item,
             :invalid_combo
           ] do
    Logger.debug("Skill #{skill_id} cast by #{character_id} silently refused: #{reason}")
  end

  def report_cast_failure(skill_id, character_id, reason) do
    Logger.debug("Skill #{skill_id} cast failed for #{character_id}: #{inspect(reason)}")
    {reason, detail} = failure_detail(reason)

    Broadcast.to_player(character_id, %SkillCastFailed{
      skill_id: skill_id,
      reason: failure_reason(reason),
      detail: detail
    })
  end

  # Spheres required and the missing equipment carry their number to the client.
  defp failure_detail({:spirits, count}), do: {:spirits, count}
  defp failure_detail({:need_equipment, item_id}), do: {:need_equipment, item_id}
  defp failure_detail(reason), do: {reason, 0}

  defp failure_reason(:missing_catalyst), do: :SKILL_CAST_FAILURE_REASON_MISSING_CATALYST
  defp failure_reason(:insufficient_sp), do: :SKILL_CAST_FAILURE_REASON_INSUFFICIENT_SP
  defp failure_reason(:insufficient_zeny), do: :SKILL_CAST_FAILURE_REASON_INSUFFICIENT_ZENY
  defp failure_reason(:no_ammo), do: :SKILL_CAST_FAILURE_REASON_NO_AMMO
  defp failure_reason(:overweight), do: :SKILL_CAST_FAILURE_REASON_OVERWEIGHT

  defp failure_reason(reason) when reason in [:on_cooldown, :skill_interval],
    do: :SKILL_CAST_FAILURE_REASON_ON_COOLDOWN

  defp failure_reason(:skill_not_learned), do: :SKILL_CAST_FAILURE_REASON_NOT_LEARNED

  defp failure_reason(reason) when reason in [:out_of_range, :no_path],
    do: :SKILL_CAST_FAILURE_REASON_OUT_OF_RANGE

  defp failure_reason(:busy), do: :SKILL_CAST_FAILURE_REASON_BUSY
  defp failure_reason(:wrong_weapon), do: :SKILL_CAST_FAILURE_REASON_WRONG_WEAPON
  defp failure_reason(:versus_map_only), do: :SKILL_CAST_FAILURE_REASON_VERSUS_MAP_ONLY
  defp failure_reason(:npc_nearby), do: :SKILL_CAST_FAILURE_REASON_NPC_NEARBY
  defp failure_reason(:to_target), do: :SKILL_CAST_FAILURE_REASON_TO_TARGET

  defp failure_reason(reason) when reason in [:hp_insufficient, :insufficient_hp],
    do: :SKILL_CAST_FAILURE_REASON_HP_INSUFFICIENT

  defp failure_reason(:spirits), do: :SKILL_CAST_FAILURE_REASON_SPIRITS
  defp failure_reason(:cart), do: :SKILL_CAST_FAILURE_REASON_CART
  defp failure_reason(:need_equipment), do: :SKILL_CAST_FAILURE_REASON_NEED_EQUIPMENT
  defp failure_reason(:skill_failed), do: :SKILL_CAST_FAILURE_REASON_FAILED
  defp failure_reason(:fullstrip_coated), do: :SKILL_CAST_FAILURE_REASON_FULLSTRIP_COATED
  defp failure_reason(:stuff_insufficient), do: :SKILL_CAST_FAILURE_REASON_STUFF_INSUFFICIENT
  defp failure_reason(_reason), do: :SKILL_CAST_FAILURE_REASON_UNSPECIFIED

  # A combo skill's use is aimed at the unit the player was attacking when the
  # request came (captured before the cast cleared the attack).
  defp aim_use(game_state, skill_id, level, target, attack_target) do
    Combo.aim(game_state, skill_id, target, attack_target, fn ->
      Interpreter.castbegin_passes?(game_state, skill_id, level, target)
    end)
  end

  defp resolve_target(%{character_id: caster_id}, target_id) when target_id == caster_id,
    do: :self

  defp resolve_target(_game_state, target_id) do
    if UnitRegistry.unit_exists?(:homunculus, target_id),
      do: {:unit, {:homunculus, target_id}},
      else: {:unit, target_id}
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

  # Damage casts broadcast their own ZC_NOTIFY_SKILL from the combat layer, so
  # the no-damage visual is sent only for a no-damage cast type. Ground casts
  # emit their own ZC_NOTIFY_GROUNDSKILL visual, so they skip this entirely.
  # A completed skill use, ordinary or automatic: shows the skill to onlookers
  # and arms the caster's on-skill procs for a no-damage or ground skill. A
  # damage skill arms them per damaging hit from the combat layer instead.
  defp broadcast_skill_use(game_state, skill_id, level, target) do
    broadcast_skill_effect(game_state, skill_id, level, target)
    CastEnd.complete(game_state, skill_id, target)
  end

  defp broadcast_skill_effect(_game_state, _skill_id, _level, {:ground, _x, _y}), do: :ok

  # Vending opens its preparation UI without a no-damage spell animation.
  defp broadcast_skill_effect(_game_state, 41, _level, _target), do: :ok

  # Brandish Spear is a no-damage cast whose only visuals are its hits.
  defp broadcast_skill_effect(_game_state, @brandish_spear, _level, _target), do: :ok

  # A Divest skill shows its effect with the strip's result once it is known.
  defp broadcast_skill_effect(_game_state, skill_id, _level, _target)
       when skill_id in @divest_skills,
       do: :ok

  # Auto Counter's cast starts no visual of its own: its stance effect reaches
  # onlookers 100 ms later, sent by the skill module itself.
  defp broadcast_skill_effect(_game_state, @auto_counter, _level, _target), do: :ok

  # A no-damage cast shows the skill's effect; a damage cast's visuals are its hits.
  defp broadcast_skill_effect(game_state, skill_id, level, target) do
    with {:ok, definition} <- Catalog.by_id(skill_id),
         :damage <- Definition.cast_type(definition) do
      :ok
    else
      _no_damage_cast ->
        packet = %SkillEffect{
          skill_id: skill_id,
          level: level,
          target_id: skill_use_target_id(game_state, target),
          src_id: game_state.character_id,
          result: 1
        }

        {map_name, x, y} = effect_origin(game_state, target)
        Broadcast.to_in_range(map_name, x, y, Config.view_range(), packet)
    end
  end

  # The effect reaches the area around its target.
  defp effect_origin(game_state, {:unit, ref}) do
    case TargetResolver.resolve_target_position(ref) do
      {:ok, _type, {x, y, map_name}} -> {map_name, x, y}
      {:error, _reason} -> {game_state.map_name, game_state.x, game_state.y}
    end
  end

  defp effect_origin(game_state, _target), do: {game_state.map_name, game_state.x, game_state.y}

  defp skill_use_target_id(%{character_id: caster_id}, :self), do: caster_id
  defp skill_use_target_id(_game_state, {:unit, {_type, id}}), do: id
  defp skill_use_target_id(_game_state, {:unit, id}), do: id
end
