defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandler do
  @moduledoc """
  Single-writer orchestration boundary between `PlayerSession` and Homunculus mechanics.
  """

  require Logger

  alias Aesir.Commons.Models.Homunculus
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.HungerHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Homunculus.PrivateStateView
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Homunculus.StateRestore
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @checkpoint_interval 5_000
  @persistence_retry_delay 100
  @adjacent_offsets [{0, -1}, {-1, 0}, {1, 0}, {0, 1}, {-1, -1}, {1, -1}, {-1, 1}, {1, 1}]

  @doc "Restores a preloaded durable row into the private, offline aggregate slot."
  @spec restore(SessionState.t(), Homunculus.t() | nil) ::
          {:ok, SessionState.t()} | {:error, atom()}
  def restore(%SessionState{} = session, nil), do: {:ok, StateCommit.restore(session, nil)}

  def restore(%SessionState{} = session, %Homunculus{} = row) do
    with {:ok, homunculus} <- StateRestore.restore(row) do
      {:ok, StateCommit.restore(session, homunculus)}
    end
  end

  def restore(%SessionState{}, _row), do: {:error, :invalid_homunculus_row}

  @doc "Resumes legal clocks and world presence after the owner enters the initial map."
  @spec spawned(SessionState.t()) ::
          {:noreply, SessionState.t()} | {:stop, term(), SessionState.t()}
  def spawned(session) when is_map(session) and not is_map_key(session, :homunculus),
    do: {:noreply, session}

  def spawned(%SessionState{} = session) when is_nil(session.homunculus), do: {:noreply, session}

  def spawned(
        %SessionState{
          homunculus_runtime: %Runtime{
            clocks_online: true,
            checkpoint_timer_ref: checkpoint_ref
          }
        } = session
      )
      when is_reference(checkpoint_ref),
      do: {:noreply, session}

  def spawned(%SessionState{} = session) do
    previous = session

    case LifecycleHandler.resume_online(session.homunculus, session.homunculus_runtime) do
      {:ok, homunculus, runtime} -> finish_spawn(previous, homunculus, runtime)
      {:noop, homunculus, runtime} -> finish_spawn(previous, homunculus, runtime)
      {:error, reason} -> stop_activation(previous, reason)
    end
  end

  @doc "Handles one ref-checked Homunculus timer event."
  @spec info(atom(), reference(), SessionState.t()) :: {:noreply, SessionState.t()}
  def info(:active_expired, ref, session), do: lifecycle_timeout(:active, ref, session)
  def info(:cooldowns_expired, ref, session), do: lifecycle_timeout(:cooldowns, ref, session)
  def info(:hunger_tick, ref, session), do: hunger_timeout(ref, session)
  def info(:checkpoint, ref, session), do: checkpoint_timeout(ref, session)

  def info(event, _ref, %SessionState{} = session) do
    Logger.warning("Unsupported Homunculus info event: #{inspect(event)}")
    {:noreply, session}
  end

  @doc "Routes an asynchronous combat event through the sole aggregate writer."
  @spec cast(term(), SessionState.t()) ::
          {:noreply, SessionState.t()} | {:stop, term(), SessionState.t()}
  def cast({:apply_damage, _gid, _damage, _hit_info, _source} = combat_event, session),
    do: CombatHandler.handle(combat_event, session)

  def cast({:apply_heal, _gid, _amount, _source} = combat_event, session),
    do: CombatHandler.handle(combat_event, session)

  def cast({:drain_sp, _gid, _amount} = combat_event, session),
    do: CombatHandler.handle(combat_event, session)

  def cast({:basic_attack, _gid, _target_ref} = combat_event, session),
    do: CombatHandler.handle(combat_event, session)

  def cast(command, %SessionState{} = session) do
    Logger.warning("Unsupported Homunculus cast: #{inspect(command)}")
    {:noreply, session}
  end

  @doc "Applies one aggregate-local Homunculus effect without messaging the owner process."
  @spec local_effect(tuple(), SessionState.t()) ::
          {:noreply, SessionState.t()} | {:stop, term(), SessionState.t()}
  def local_effect({:homunculus, event}, %SessionState{} = session),
    do: CombatHandler.handle(event, session)

  @doc "Applies aggregate-local effects in list order through the current session state."
  @spec local_effects([tuple()], SessionState.t()) ::
          {:noreply, SessionState.t()} | {:stop, term(), SessionState.t()}
  def local_effects(effects, %SessionState{} = session) when is_list(effects) do
    Enum.reduce_while(effects, {:noreply, session}, fn effect, {:noreply, current} ->
      case local_effect(effect, current) do
        {:noreply, updated} -> {:cont, {:noreply, updated}}
        {:stop, _reason, _state} = stop -> {:halt, stop}
      end
    end)
  end

  @doc "Stable future command call route; Task 24 supplies concrete commands."
  @spec call(term(), GenServer.from(), SessionState.t()) ::
          {:reply, {:error, :unsupported}, SessionState.t()}
  def call(command, _from, %SessionState{} = session) do
    Logger.warning("Unsupported Homunculus call: #{inspect(command)}")
    {:reply, {:error, :unsupported}, session}
  end

  @doc "Detaches active presence before the owner leaves the old warp map."
  @spec detach_for_warp(map()) :: map()
  def detach_for_warp(%SessionState{} = session), do: StateCommit.detach(session)
  def detach_for_warp(session) when is_map(session), do: session

  @doc """
  Re-enters active presence adjacent to the owner without changing clocks or GID.

  If all eight adjacent terrain cells are blocked, the Homunculus shares the
  owner's accepted destination cell rather than remaining registered on the old map.
  """
  @spec entered_after_warp(SessionState.t()) :: {:noreply, SessionState.t()}
  def entered_after_warp(session) when is_map(session) and not is_map_key(session, :homunculus),
    do: {:noreply, session}

  def entered_after_warp(%SessionState{} = session) when is_nil(session.homunculus),
    do: {:noreply, session}

  def entered_after_warp(%SessionState{} = session) do
    session =
      if session.homunculus.lifecycle == :active do
        owner = session.game_state
        {x, y} = adjacent_cell(owner.map_name, owner.x, owner.y)

        homunculus = %{
          session.homunculus
          | map_name: owner.map_name,
            x: x,
            y: y,
            dir: owner.dir,
            owner_session_pid: self()
        }

        StateCommit.commit(session, homunculus)
      else
        session
      end

    session
    |> send_private_state()
    |> then(&{:noreply, &1})
  end

  @doc "Applies the authoritative owner-death lifecycle rule after player death commits."
  @spec owner_died(SessionState.t()) :: SessionState.t()
  def owner_died(session) when is_map(session) and not is_map_key(session, :homunculus),
    do: session

  def owner_died(%SessionState{} = session) when is_nil(session.homunculus), do: session

  def owner_died(%SessionState{} = session) do
    case LifecycleHandler.owner_died(session.homunculus, session.homunculus_runtime) do
      {:ok, homunculus, runtime} -> persist_and_commit(session, homunculus, runtime, :owner_death)
      {:noop, _homunculus, _runtime} -> session
      {:error, reason} -> log_error(session, :owner_death, reason)
    end
  end

  @doc "Pauses and flushes clocks, then idempotently clears all Homunculus world presence."
  @spec terminate(SessionState.t()) :: SessionState.t()
  def terminate(session) when is_map(session) and not is_map_key(session, :homunculus),
    do: session

  def terminate(%SessionState{} = session) when is_nil(session.homunculus), do: session

  def terminate(%SessionState{} = session) do
    case LifecycleHandler.pause_offline(session.homunculus, session.homunculus_runtime) do
      {:ok, homunculus, runtime} ->
        finish_termination(session, homunculus, runtime)

      {:noop, homunculus, runtime} ->
        finish_termination(session, homunculus, runtime)

      {:error, reason} ->
        log_error(session, :terminate_pause, reason)
        StateCommit.clear_presence(session, session.homunculus)
    end
  end

  defp finish_spawn(previous, homunculus, runtime) do
    session = %{previous | homunculus_runtime: runtime}

    case activate_if_needed(session, homunculus) do
      {:ok, session} ->
        {_result, _homunculus, runtime} =
          HungerHandler.arm(session.homunculus, session.homunculus_runtime)

        session =
          session
          |> Map.put(:homunculus_runtime, runtime)
          |> arm_checkpoint()
          |> send_private_state()

        {:noreply, session}

      {:error, reason} ->
        stop_activation(%{previous | homunculus_runtime: runtime}, reason)
    end
  end

  defp activate_if_needed(session, %HomunculusState{lifecycle: :active} = homunculus),
    do: StateCommit.activate(session, homunculus)

  defp activate_if_needed(session, homunculus), do: {:ok, StateCommit.commit(session, homunculus)}

  defp stop_activation(session, reason) do
    cancel_runtime(session.homunculus_runtime)
    Logger.error("Homunculus activation failed: #{inspect(reason)}")
    {:stop, {:homunculus_activation_failed, reason}, session}
  end

  defp lifecycle_timeout(_kind, _ref, %SessionState{} = session)
       when is_nil(session.homunculus),
       do: {:noreply, session}

  defp lifecycle_timeout(:active, ref, session) do
    result = LifecycleHandler.expire(session.homunculus, session.homunculus_runtime, ref)
    finish_lifecycle_timeout(session, result, :active_expiry)
  end

  defp lifecycle_timeout(:cooldowns, ref, session) do
    result =
      LifecycleHandler.cooldowns_expired(session.homunculus, session.homunculus_runtime, ref)

    finish_lifecycle_timeout(session, result, :cooldown_expiry)
  end

  defp finish_lifecycle_timeout(session, {:ok, homunculus, runtime}, operation) do
    {:noreply, persist_and_commit(session, homunculus, runtime, operation)}
  end

  defp finish_lifecycle_timeout(session, {:noop, _homunculus, _runtime}, _operation),
    do: {:noreply, session}

  defp finish_lifecycle_timeout(session, {:error, reason}, operation) do
    {:noreply, log_error(session, operation, reason)}
  end

  defp hunger_timeout(_ref, %SessionState{} = session) when is_nil(session.homunculus),
    do: {:noreply, session}

  defp hunger_timeout(ref, session) do
    inventory = session.game_state.inventory

    case HungerHandler.tick(
           session.homunculus,
           session.homunculus_runtime,
           inventory,
           ref
         ) do
      {:ok, homunculus, runtime, ^inventory} ->
        session =
          session |> Map.put(:homunculus_runtime, runtime) |> StateCommit.commit(homunculus)

        {:noreply, session}

      {:noop, _homunculus, runtime, ^inventory} ->
        {:noreply, %{session | homunculus_runtime: runtime}}

      {:error, reason, _homunculus, runtime, ^inventory} ->
        Logger.error("Homunculus hunger tick failed: #{inspect(reason)}")
        {:noreply, %{session | homunculus_runtime: runtime}}
    end
  end

  defp checkpoint_timeout(ref, session) do
    if Clock.current_timer?(session.homunculus_runtime.checkpoint_timer_ref, ref) do
      session = checkpoint(session, :periodic)
      {:noreply, arm_checkpoint(session)}
    else
      {:noreply, session}
    end
  end

  defp checkpoint(%SessionState{} = session, _operation) when is_nil(session.homunculus),
    do: session

  defp checkpoint(session, operation) do
    now_ms = Clock.now_ms()

    with {:ok, clocks} <-
           durable_clock_snapshot(session.homunculus, session.homunculus_runtime, now_ms),
         %Homunculus{id: id} = row <-
           Persistence.load_for_character(session.game_state.character_id),
         true <- id == session.homunculus.id,
         {:ok, _row} <-
           Persistence.checkpoint(row, %{
             hp: session.homunculus.hp,
             sp: session.homunculus.sp,
             active_remaining_ms: clocks.active_remaining_ms,
             cooldowns: clocks.cooldowns
           }) do
      session
    else
      reason -> log_error(session, operation, reason)
    end
  end

  defp persist_and_commit(session, homunculus, runtime, operation) do
    now_ms = Clock.now_ms()

    with %Homunculus{id: id} = row <-
           Persistence.load_for_character(session.game_state.character_id),
         true <- id == session.homunculus.id,
         {:ok, clocks} <-
           Clock.durable_snapshot(
             homunculus.lifecycle,
             runtime.active_deadline_ms,
             homunculus.cooldowns,
             now_ms
           ),
         attrs <-
           homunculus
           |> ProgressionHandler.persistence_attrs()
           |> Map.put(:active_remaining_ms, clocks.active_remaining_ms)
           |> Map.put(:cooldowns, clocks.cooldowns),
         {:ok, _row} <- Persistence.save_semantic(row, attrs) do
      session
      |> Map.put(:homunculus_runtime, runtime)
      |> StateCommit.commit(homunculus)
    else
      reason -> recover_persist_failure(session, homunculus, runtime, operation, reason, now_ms)
    end
  end

  defp recover_persist_failure(session, homunculus, runtime, operation, reason, now_ms) do
    log_error(session, operation, reason)

    case operation do
      :owner_death -> retry_owner_death(session, now_ms)
      :active_expiry -> retry_active_expiry(session, homunculus, runtime, now_ms)
      :cooldown_expiry -> retry_cooldown_expiry(session, homunculus, runtime, now_ms)
    end
  end

  defp retry_owner_death(session, now_ms) do
    runtime = rearm_old_active(session.homunculus_runtime, now_ms)
    %{session | homunculus_runtime: runtime}
  end

  defp retry_active_expiry(session, homunculus, runtime, now_ms) do
    if homunculus == session.homunculus do
      %{session | homunculus_runtime: runtime}
    else
      Clock.cancel(runtime.active_expiry_timer_ref)
      runtime = rearm_old_active(session.homunculus_runtime, now_ms)
      %{session | homunculus_runtime: runtime}
    end
  end

  defp retry_cooldown_expiry(session, homunculus, runtime, now_ms) do
    if homunculus.cooldowns == session.homunculus.cooldowns do
      %{session | homunculus_runtime: runtime}
    else
      Clock.cancel(runtime.cooldown_timer_ref)
      runtime = rearm_old_cooldowns(session.homunculus, session.homunculus_runtime, now_ms)
      %{session | homunculus_runtime: runtime}
    end
  end

  defp rearm_old_active(%Runtime{active_deadline_ms: deadline} = runtime, now_ms) do
    retry_deadline = max(deadline, now_ms + @persistence_retry_delay)
    ref = Clock.arm_active(retry_deadline, now_ms)
    %{runtime | active_expiry_timer_ref: ref}
  end

  defp rearm_old_cooldowns(homunculus, runtime, now_ms) do
    retry_deadline = now_ms + @persistence_retry_delay

    delayed =
      Map.new(homunculus.cooldowns, fn {id, deadline} -> {id, max(deadline, retry_deadline)} end)

    ref = Clock.arm_nearest_cooldown(delayed, now_ms)
    %{runtime | cooldown_timer_ref: ref}
  end

  defp durable_clock_snapshot(homunculus, %Runtime{clocks_online: true} = runtime, now_ms) do
    Clock.durable_snapshot(
      homunculus.lifecycle,
      runtime.active_deadline_ms,
      homunculus.cooldowns,
      now_ms
    )
  end

  defp durable_clock_snapshot(homunculus, %Runtime{clocks_online: false}, _now_ms) do
    {:ok,
     %{
       active_remaining_ms: homunculus.active_remaining_ms,
       cooldowns: homunculus.cooldowns
     }}
  end

  defp finish_termination(session, homunculus, runtime) do
    {:noop, _homunculus, runtime} = HungerHandler.arm(homunculus, runtime)
    Clock.cancel(runtime.checkpoint_timer_ref)
    runtime = %{runtime | checkpoint_timer_ref: nil}
    session = %{session | homunculus_runtime: runtime}
    session = flush_checkpoint(session, homunculus, runtime, :terminate_checkpoint)
    StateCommit.clear_presence(session, homunculus)
  end

  defp flush_checkpoint(session, homunculus, runtime, operation) do
    with %Homunculus{id: id} = row <-
           Persistence.load_for_character(session.game_state.character_id),
         true <- id == homunculus.id,
         {:ok, clocks} <- durable_clock_snapshot(homunculus, runtime, Clock.now_ms()),
         {:ok, _row} <-
           Persistence.checkpoint(row, %{
             hp: homunculus.hp,
             sp: homunculus.sp,
             active_remaining_ms: clocks.active_remaining_ms,
             cooldowns: clocks.cooldowns
           }) do
      session
    else
      reason -> log_error(session, operation, reason)
    end
  end

  defp arm_checkpoint(%SessionState{} = session) when is_nil(session.homunculus), do: session

  defp arm_checkpoint(%SessionState{} = session) do
    Clock.cancel(session.homunculus_runtime.checkpoint_timer_ref)
    ref = :erlang.start_timer(@checkpoint_interval, self(), {:homunculus, :checkpoint})
    runtime = %{session.homunculus_runtime | checkpoint_timer_ref: ref}
    %{session | homunculus_runtime: runtime}
  end

  defp send_private_state(%SessionState{} = session) when is_nil(session.homunculus), do: session

  defp send_private_state(%SessionState{} = session) do
    packet = PrivateStateView.build(session.homunculus, session.homunculus_runtime)
    MessageRouter.send_to(session.connection_pid, packet)
    runtime = %{session.homunculus_runtime | private_dirty: false}
    %{session | homunculus_runtime: runtime}
  end

  defp adjacent_cell(map_name, x, y) do
    Enum.find_value(@adjacent_offsets, {x, y}, fn {dx, dy} ->
      cell = {x + dx, y + dy}
      if Cell.traversable?(map_name, elem(cell, 0), elem(cell, 1)), do: cell
    end)
  end

  defp cancel_runtime(runtime) do
    Enum.each(
      [
        runtime.active_expiry_timer_ref,
        runtime.cooldown_timer_ref,
        runtime.hunger_timer_ref,
        runtime.checkpoint_timer_ref
      ],
      &Clock.cancel/1
    )
  end

  defp log_error(session, operation, reason) do
    Logger.error("Homunculus #{operation} failed: #{inspect(reason)}")
    session
  end
end
