defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandler do
  @moduledoc """
  Single-writer orchestration boundary between `PlayerSession` and Homunculus mechanics.
  """

  require Logger

  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Net.HomunculusRequest
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config, as: AiConfig
  alias Aesir.ZoneServer.Mmo.Homunculus.LifecycleSkills
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CastlingHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.HungerHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.RequestProtocol
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Homunculus.PrivateStateView
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime
  alias Aesir.ZoneServer.Unit.Homunculus.SpawnView
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Homunculus.StateRestore
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

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
  @spec info(term(), reference(), SessionState.t()) ::
          {:noreply, SessionState.t()} | {:stop, term(), SessionState.t()}
  def info({:cast_complete, token}, ref, session),
    do: CastingHandler.complete(ref, token, session)

  def info(:bio_explosion, ref, session),
    do: CastingHandler.resolve_bio_explosion(ref, session)

  def info(:active_expired, ref, session), do: lifecycle_timeout(:active, ref, session)
  def info(:cooldowns_expired, ref, session), do: lifecycle_timeout(:cooldowns, ref, session)
  def info(:hunger_tick, ref, session), do: hunger_timeout(ref, session)
  def info(:checkpoint, ref, session), do: checkpoint_timeout(ref, session)
  def info(:ai_tick, ref, session), do: AiHandler.tick(ref, session)

  def info(:movement_tick, ref, session),
    do: {:noreply, MovementHandler.tick(ref, session)}

  def info(:separation_timeout, ref, session),
    do: {:noreply, MovementHandler.separation_timeout(ref, session)}

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

  def cast({:status_changed, _gid, _status_id, _event} = status_event, session),
    do: CombatHandler.handle(status_event, session)

  def cast({:gain_exp, _gid, 0, _mob_map}, %SessionState{} = session),
    do: {:noreply, session}

  def cast(
        {:gain_exp, gid, amount, mob_map},
        %SessionState{
          game_state: %{map_name: mob_map},
          homunculus: %HomunculusState{world_gid: gid, map_name: mob_map} = homunculus
        } = session
      )
      when is_integer(amount) and amount > 0 do
    if HomunculusState.living?(homunculus) do
      case ProgressionHandler.gain_exp(homunculus, amount) do
        {:ok, progressed} -> {:noreply, StateCommit.commit(session, progressed)}
        {:error, reason} -> {:noreply, log_error(session, :gain_exp, reason)}
      end
    else
      {:noreply, session}
    end
  end

  def cast({:gain_exp, _gid, _amount, _mob_map}, %SessionState{} = session),
    do: {:noreply, session}

  def cast(command, %SessionState{} = session) do
    Logger.warning("Unsupported Homunculus cast: #{inspect(command)}")
    {:noreply, session}
  end

  @type local_effect_result ::
          {:noreply, SessionState.t()}
          | {:error, atom(), SessionState.t()}
          | {:stop, term(), SessionState.t()}

  @doc "Applies one aggregate-local Homunculus effect without messaging the owner process."
  @spec local_effect(tuple(), SessionState.t()) :: local_effect_result()
  def local_effect(
        {:homunculus, {:castling_swap, gid}},
        %SessionState{
          game_state: %PlayerState{},
          homunculus: %HomunculusState{world_gid: gid}
        } = session
      ),
      do: CastlingHandler.swap(session, gid)

  def local_effect({:homunculus, event}, %SessionState{} = session),
    do: CombatHandler.handle(event, session)

  def local_effect({:player, {:apply_heal, amount, source}}, %SessionState{} = session),
    do: HealthHandler.apply_heal(amount, source_id(source), session)

  def local_effect({:player, {:apply_damage, amount, source}}, %SessionState{} = session),
    do: HealthHandler.apply_damage(amount, source_id(source), session)

  def local_effect({:prepared_external_hit, prepared}, %SessionState{} = session) do
    :ok = SkillAttack.deliver_prepared_skill_hit(prepared)
    {:noreply, session}
  end

  def local_effect({:mob, {:apply_heal, id, amount, source}}, %SessionState{} = session) do
    :ok = DamageApplication.apply_heal(:mob, id, amount, source)
    {:noreply, session}
  end

  @doc "Applies aggregate-local effects in list order through the current session state."
  @spec local_effects([tuple()], SessionState.t()) :: local_effect_result()
  def local_effects(effects, %SessionState{} = session) when is_list(effects) do
    Enum.reduce_while(effects, {:noreply, session}, fn effect, {:noreply, current} ->
      case local_effect(effect, current) do
        {:noreply, updated} -> {:cont, {:noreply, updated}}
        {:error, _reason, _state} = error -> {:halt, error}
        {:stop, _reason, _state} = stop -> {:halt, stop}
      end
    end)
  end

  @doc "Executes one channel-vetted owner request inline in the player aggregate."
  @spec request(HomunculusRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()} | {:stop, term(), SessionState.t()}
  def request(%HomunculusRequest{} = request, %SessionState{} = session) do
    {outcome, updated} =
      with :ok <- RequestProtocol.validate_request(request),
           {:ok, command} <- RequestProtocol.decode_command(request.command),
           :ok <- require_companion(session) do
        case execute(command, session) do
          {:ok, next} -> {{:ok, nil}, next}
          {:error, reason, unchanged} -> {{:error, reason}, unchanged}
          {:stop, reason, stopped} -> {{:stop, reason}, stopped}
        end
      else
        {:error, reason} -> {{:error, reason}, session}
      end

    result = RequestProtocol.build_result(request.request_id, outcome, updated)
    MessageRouter.send_to(session.connection_pid, result)
    updated = clear_result_dirty(updated)

    case outcome do
      {:stop, reason} -> {:stop, reason, updated}
      _other -> {:noreply, updated}
    end
  end

  @doc "Keeps the synchronous namespaced aggregate seam compatible for server callers."
  @spec call(term(), GenServer.from(), SessionState.t()) ::
          {:reply, :ok | {:error, atom()}, SessionState.t()}
          | {:stop, term(), {:error, atom()}, SessionState.t()}
  def call(command, _from, %SessionState{} = session) do
    case execute(command, session) do
      {:ok, updated} -> {:reply, :ok, updated}
      {:error, reason, unchanged} -> {:reply, {:error, reason}, unchanged}
      {:stop, reason, stopped} -> {:stop, reason, {:error, reason}, stopped}
    end
  end

  defp require_companion(%SessionState{} = session) do
    if match?(%HomunculusState{}, session.homunculus),
      do: :ok,
      else: {:error, :no_companion}
  end

  defp execute(:inspect, session), do: {:ok, session}

  defp execute({:move, x, y}, session) do
    with :ok <- require_actionable(session),
         :ok <- MovementHandler.validate_destination(session, {x, y}) do
      {:ok, MovementHandler.move_to(session, {x, y})}
    else
      {:error, reason} -> {:error, reason, session}
    end
  end

  defp execute(:follow, session) do
    with :ok <- require_actionable(session),
         {:ok, updated} <- MovementHandler.follow_result(session) do
      {:ok, updated}
    else
      {:error, reason, unchanged} -> {:error, reason, unchanged}
      {:error, reason} -> {:error, reason, session}
    end
  end

  defp execute({:attack, target_id}, session) do
    with :ok <- require_actionable(session),
         {:ok, target_ref} <- command_target_ref(session, target_id) do
      CombatHandler.basic_attack(session, session.homunculus.world_gid, target_ref)
    else
      {:error, reason} -> {:error, reason, session}
    end
  end

  defp execute(:standby, session) do
    case require_actionable(session) do
      :ok -> {:ok, MovementHandler.standby(session)}
      {:error, reason} -> {:error, reason, session}
    end
  end

  defp execute({:cast_skill, skill_id, level, wire_target}, session) do
    with :ok <- require_living(session),
         :ok <- SkillInterpreter.preflight_homunculus_skill(session.homunculus, skill_id, level),
         {:ok, target} <- cast_target(session, wire_target) do
      case CastingHandler.begin(session, skill_id, level, target) do
        {:ok, updated} -> {:ok, updated}
        {:error, reason, unchanged} -> {:error, reason, unchanged}
        {:stop, reason, stopped} -> {:stop, reason, stopped}
      end
    else
      {:error, reason} -> {:error, reason, session}
    end
  end

  defp execute(:feed, session) do
    inventory = session.game_state.inventory

    with :ok <- require_living(session),
         {:ok, index} <- HungerHandler.food_index(session.homunculus.class_id, inventory) do
      finish_feed(session, inventory, index)
    else
      {:error, reason} -> {:error, reason, session}
    end
  end

  defp execute({:rename, raw_name}, session) do
    with :ok <- require_rename_available(session.homunculus),
         {:ok, name} <- normalize_name(raw_name),
         updated = %{session.homunculus | name: name, rename_available: false},
         :ok <- persist_fields(session.homunculus, %{name: name, rename_available: false}) do
      committed = StateCommit.commit(session, updated)
      refresh_renamed_observers(updated)
      {:ok, committed}
    else
      {:error, reason} -> {:error, reason, session}
    end
  end

  defp execute(:rest, session) do
    if Unit.living?(session.game_state) do
      SkillHandler.execute_lifecycle_skill(session, LifecycleSkills.rest_id(), 1)
    else
      {:error, :owner_dead, session}
    end
  end

  defp execute({:delete, confirmed}, session) do
    case LifecycleHandler.delete(
           session.homunculus,
           session.homunculus_runtime,
           confirmed,
           timer_cancel: &ignore_timer_cancel/1
         ) do
      {:ok, nil, _runtime} -> finish_delete(session)
      {:error, reason} -> {:error, reason, session}
    end
  end

  defp execute({:replace_ai, wire_config}, session) do
    with {:ok, specs} <- StateRestore.ai_skill_specs(session.homunculus.learned_skills),
         {:ok, config} <- AiConfig.decode(RequestProtocol.ai_persisted_map(wire_config), specs) do
      case persist_fields(session.homunculus, %{ai_config: AiConfig.encode(config)}) do
        :ok -> {:ok, StateCommit.commit(session, %{session.homunculus | ai_config: config})}
        {:error, reason} -> {:error, reason, session}
      end
    else
      {:error, _reason} -> {:error, :invalid_ai_config, session}
    end
  end

  defp execute({:learn_skill, skill_id}, session) when is_integer(skill_id) and skill_id > 0 do
    case ProgressionHandler.learn_skill(session.homunculus, skill_id) do
      {:ok, homunculus} -> {:ok, StateCommit.commit(session, homunculus)}
      {:error, reason} -> {:error, reason, session}
    end
  end

  defp execute(_command, session), do: {:error, :malformed, session}

  defp require_living(%SessionState{} = session) do
    if match?(%HomunculusState{}, session.homunculus) and
         HomunculusState.living?(session.homunculus),
       do: :ok,
       else: {:error, :invalid_lifecycle}
  end

  defp require_actionable(%SessionState{} = session) do
    with :ok <- require_living(session),
         %HomunculusState{action_state: action, movement_state: movement} <- session.homunculus,
         true <- action != :casting and movement == :standing do
      :ok
    else
      false -> {:error, :busy}
      {:error, _reason} = error -> error
    end
  end

  defp command_target_ref(session, target_id) do
    cond do
      target_id == session.game_state.character_id -> {:ok, {:player, target_id}}
      target_id == session.homunculus.world_gid -> {:ok, {:homunculus, target_id}}
      true -> registered_target_ref(target_id)
    end
  end

  defp registered_target_ref(target_id) do
    player = UnitRegistry.get_unit(:player, target_id)
    homunculus = UnitRegistry.get_unit(:homunculus, target_id)

    case {player, homunculus} do
      {{:ok, _player}, {:ok, _homunculus}} -> {:error, :invalid_target}
      {{:ok, _player}, _missing} -> {:ok, {:player, target_id}}
      {_missing, {:ok, _homunculus}} -> {:ok, {:homunculus, target_id}}
      {_missing_player, _missing_homunculus} -> {:ok, {:mob, target_id}}
    end
  end

  defp cast_target(_session, {:self, true}), do: {:ok, :self}
  defp cast_target(_session, {:self, _false}), do: {:error, :malformed}

  defp cast_target(session, {:target_id, target_id}) when target_id > 0 do
    with {:ok, target_ref} <- command_target_ref(session, target_id) do
      {:ok, {:unit, target_ref}}
    end
  end

  defp cast_target(_session, _target), do: {:error, :malformed}

  defp finish_feed(session, inventory, index) do
    case HungerHandler.feed(
           session.homunculus,
           session.homunculus_runtime,
           inventory
         ) do
      {:ok, homunculus, runtime, new_inventory} ->
        updated =
          if is_nil(homunculus) do
            clear_companion_runtime(session)
          else
            %{session | homunculus_runtime: runtime}
          end

        updated = %{updated | game_state: %{session.game_state | inventory: new_inventory}}
        committed = StateCommit.commit(updated, homunculus)
        MessageRouter.send_to(session.connection_pid, InventoryView.item_removed(index, 1))
        {:ok, committed}

      {:error, reason, _homunculus, _runtime, ^inventory} ->
        {:error, reason, session}
    end
  end

  defp finish_delete(session) do
    case Persistence.load_for_character(session.game_state.character_id) do
      %Homunculus{id: id} = row when id == session.homunculus.id ->
        case Persistence.delete(row, session.game_state.inventory) do
          {:ok, inventory, nil} ->
            updated = clear_companion_runtime(session)
            updated = %{updated | game_state: %{session.game_state | inventory: inventory}}
            {:ok, StateCommit.commit(updated, nil)}

          {:error, reason} ->
            {:error, reason, session}
        end

      _missing ->
        {:error, :not_persisted, session}
    end
  end

  defp persist_fields(%HomunculusState{} = homunculus, attrs) do
    case Persistence.load_for_character(homunculus.owner_character_id) do
      %Homunculus{id: id} = row when id == homunculus.id ->
        case Persistence.save_semantic(row, attrs) do
          {:ok, _row} -> :ok
          {:error, reason} -> {:error, {:persistence, reason}}
        end

      _missing ->
        {:error, :not_persisted}
    end
  end

  defp require_rename_available(%HomunculusState{rename_available: true}), do: :ok

  defp require_rename_available(%HomunculusState{}),
    do: {:error, :rename_not_allowed}

  defp normalize_name(name) when is_binary(name) do
    if String.valid?(name) do
      normalized = name |> String.normalize(:nfc) |> String.trim()

      if String.length(normalized) in 1..23,
        do: {:ok, normalized},
        else: {:error, :invalid_name}
    else
      {:error, :invalid_name}
    end
  end

  defp normalize_name(_name), do: {:error, :invalid_name}

  defp refresh_renamed_observers(%HomunculusState{world_gid: gid} = homunculus)
       when is_integer(gid) do
    homunculus.map_name
    |> SpatialIndex.get_players_in_range(homunculus.x, homunculus.y, Config.view_range())
    |> Enum.each(fn observer_id ->
      SpawnView.send_despawn(observer_id, gid)
      SpawnView.send_spawn(observer_id, homunculus)
    end)
  end

  defp refresh_renamed_observers(%HomunculusState{}), do: :ok

  defp ignore_timer_cancel(_ref), do: :ok

  defp clear_result_dirty(%SessionState{} = session) do
    runtime = %{session.homunculus_runtime | private_dirty: false}
    %{session | homunculus_runtime: runtime}
  end

  @doc "Detaches active presence before the owner leaves the old warp map."
  @spec detach_for_warp(map(), boolean()) :: map()
  def detach_for_warp(%SessionState{} = session, false) do
    session = cancel_active_runtime(session)

    case session.homunculus do
      %HomunculusState{world_gid: gid} when is_integer(gid) ->
        StatusInterpreter.remove_on_map_change(:homunculus, gid)

      _other ->
        :ok
    end

    StateCommit.detach(session)
  end

  def detach_for_warp(%SessionState{} = session, true),
    do: session |> cancel_active_runtime() |> StateCommit.detach()

  def detach_for_warp(session, same_map?) when is_map(session) and is_boolean(same_map?),
    do: session

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
    |> arm_active_runtime()
    |> send_private_state()
    |> then(&{:noreply, &1})
  end

  @doc "Applies the authoritative owner-death lifecycle rule after player death commits."
  @spec owner_died(SessionState.t()) :: SessionState.t()
  def owner_died(session) when is_map(session) and not is_map_key(session, :homunculus),
    do: session

  def owner_died(%SessionState{} = session) when is_nil(session.homunculus), do: session

  def owner_died(%SessionState{} = session) do
    session = session |> CastingHandler.cancel() |> CastingHandler.cancel_bio_explosion()

    case LifecycleHandler.owner_died(session.homunculus, session.homunculus_runtime) do
      {:ok, homunculus, runtime} ->
        session
        |> persist_and_commit(homunculus, runtime, :owner_death)
        |> reconcile_active_runtime()

      {:noop, _homunculus, _runtime} ->
        session

      {:error, reason} ->
        log_error(session, :owner_death, reason)
    end
  end

  @doc "Pauses and flushes clocks, then idempotently clears all Homunculus world presence."
  @spec terminate(SessionState.t()) :: SessionState.t()
  def terminate(session) when is_map(session) and not is_map_key(session, :homunculus),
    do: session

  def terminate(%SessionState{} = session) when is_nil(session.homunculus), do: session

  def terminate(%SessionState{} = session) do
    session = session |> CastingHandler.cancel() |> cancel_active_runtime()

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
        session =
          session
          |> arm_active_runtime()
          |> StateCommit.restore_lifecycle_cooldowns()
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
    Clock.cancel_all(session.homunculus_runtime)
    Logger.error("Homunculus activation failed: #{inspect(reason)}")
    {:stop, {:homunculus_activation_failed, reason}, session}
  end

  defp lifecycle_timeout(_kind, _ref, %SessionState{} = session)
       when is_nil(session.homunculus),
       do: {:noreply, session}

  defp lifecycle_timeout(:active, ref, session) do
    session =
      if Clock.current_timer?(session.homunculus_runtime.active_expiry_timer_ref, ref) do
        session |> CastingHandler.cancel() |> CastingHandler.cancel_bio_explosion()
      else
        session
      end

    result = LifecycleHandler.expire(session.homunculus, session.homunculus_runtime, ref)
    finish_lifecycle_timeout(session, result, :active_expiry)
  end

  defp lifecycle_timeout(:cooldowns, ref, session) do
    result =
      LifecycleHandler.cooldowns_expired(session.homunculus, session.homunculus_runtime, ref)

    finish_lifecycle_timeout(session, result, :cooldown_expiry)
  end

  defp finish_lifecycle_timeout(session, {:ok, homunculus, runtime}, operation) do
    updated =
      session
      |> persist_and_commit(homunculus, runtime, operation)
      |> StateCommit.sync_owner_lifecycle_cooldowns()
      |> reconcile_active_runtime()

    {:noreply, updated}
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
          session
          |> Map.put(:homunculus_runtime, runtime)
          |> StateCommit.commit(homunculus)
          |> reconcile_active_runtime()

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
    runtime = Clock.cancel_field(session.homunculus_runtime, :checkpoint_timer_ref)
    ref = Clock.arm(@checkpoint_interval, :checkpoint)
    %{session | homunculus_runtime: %{runtime | checkpoint_timer_ref: ref}}
  end

  @doc "Arms the bounded active runtime without allocating or activating world identity."
  @spec arm_active_runtime(SessionState.t()) :: SessionState.t()
  def arm_active_runtime(%SessionState{} = session) do
    session = arm_checkpoint(session)

    if match?(%HomunculusState{}, session.homunculus) and
         HomunculusState.living?(session.homunculus) do
      {_result, _homunculus, runtime} =
        HungerHandler.arm(session.homunculus, session.homunculus_runtime)

      session
      |> Map.put(:homunculus_runtime, runtime)
      |> AiHandler.arm()
      |> MovementHandler.sync_separation()
    else
      cancel_active_runtime(session)
    end
  end

  @doc "Cancels AI, movement, and separation bookkeeping for inactive lifecycle transitions."
  @spec cancel_active_runtime(SessionState.t()) :: SessionState.t()
  def cancel_active_runtime(%SessionState{} = session) do
    session
    |> AiHandler.cancel()
    |> MovementHandler.cancel()
    |> CastingHandler.cancel_bio_explosion()
  end

  @doc "Clears every companion-owned timer and transient field before permanent removal."
  @spec clear_companion_runtime(SessionState.t()) :: SessionState.t()
  def clear_companion_runtime(%SessionState{} = session) do
    Clock.cancel_all(session.homunculus_runtime)
    %{session | homunculus_runtime: %Runtime{private_dirty: false}}
  end

  @doc "Stops hunger plus action timers after Rest, death, or deletion."
  @spec deactivate_runtime(SessionState.t()) :: SessionState.t()
  def deactivate_runtime(%SessionState{} = session) do
    session = cancel_active_runtime(session)

    case session.homunculus do
      %HomunculusState{} = homunculus ->
        {_result, _homunculus, runtime} =
          HungerHandler.arm(homunculus, session.homunculus_runtime)

        %{session | homunculus_runtime: runtime}

      nil ->
        session
    end
  end

  @doc "Publishes one private snapshot only when aggregate mutations marked it dirty."
  @spec publish_private_state_if_dirty(SessionState.t()) :: SessionState.t()
  def publish_private_state_if_dirty(
        %SessionState{homunculus_runtime: %Runtime{private_dirty: true}} = session
      ),
      do: send_private_state(session)

  def publish_private_state_if_dirty(%SessionState{} = session), do: session

  defp reconcile_active_runtime(session) do
    if match?(%HomunculusState{}, session.homunculus) and
         HomunculusState.living?(session.homunculus),
       do: session,
       else: deactivate_runtime(session)
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

  defp source_id({_type, id}) when is_integer(id), do: id
  defp source_id(id) when is_integer(id) or is_nil(id), do: id

  defp log_error(session, operation, reason) do
    Logger.error("Homunculus #{operation} failed: #{inspect(reason)}")
    session
  end
end
