defmodule Aesir.ZoneServer.Unit.Player.Handlers.SpiritSphereHandler do
  @moduledoc """
  Applies spirit-sphere changes inside the owning player session.
  """

  alias Aesir.Net.SpiritSphereUpdate
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.Player.StateCommit

  @type session_state :: %{
          required(:game_state) => PlayerState.t(),
          required(:connection_pid) => pid()
        }

  @spec summon(session_state(), pos_integer(), pos_integer()) :: {:noreply, session_state()}
  def summon(%{game_state: game_state} = state, duration, cap) when duration > 0 and cap > 0 do
    now = System.monotonic_time(:millisecond)

    case SpiritSpheres.summon(game_state.spirit_spheres, now + duration, cap) do
      {spheres, %SpiritSpheres.Entry{}} -> {:noreply, commit(state, spheres, now, true)}
      {:error, :all_reserved} -> {:noreply, state}
    end
  end

  @spec consume(session_state(), pos_integer()) ::
          {:ok, session_state()} | {:error, :insufficient}
  def consume(%{game_state: game_state} = state, count) when count > 0 do
    case SpiritSpheres.consume(game_state.spirit_spheres, count) do
      {:ok, spheres, _entries} ->
        {:ok, commit(state, spheres, System.monotonic_time(:millisecond), true)}

      {:error, :insufficient} = error ->
        error
    end
  end

  @spec reserve(session_state(), term(), pos_integer()) ::
          {:ok, session_state(), [SpiritSpheres.Entry.t()]}
          | {:error, :insufficient | :operation_mismatch | :pending_operation}
  def reserve(
        %{game_state: %{pending_spirit_sphere_action: nil} = game_state} = state,
        operation_id,
        count
      )
      when count > 0 do
    case SpiritSpheres.reserve(game_state.spirit_spheres, operation_id, count) do
      {:ok, spheres, entries} ->
        game_state = %{
          game_state
          | spirit_spheres: spheres,
            pending_spirit_sphere_action: %{
              operation_id: operation_id,
              entry_ids: Enum.map(entries, & &1.id)
            }
        }

        {:ok, StateCommit.commit(state, game_state), entries}

      {:error, :insufficient} = error ->
        error
    end
  end

  def reserve(
        %{
          game_state:
            %{
              pending_spirit_sphere_action: %{
                operation_id: operation_id,
                entry_ids: expected_entry_ids
              }
            } = game_state
        } = state,
        operation_id,
        count
      )
      when count > 0 do
    entries = SpiritSpheres.reserved(game_state.spirit_spheres, operation_id)
    entry_ids = Enum.map(entries, & &1.id)

    if entry_ids == expected_entry_ids and length(expected_entry_ids) == count do
      {:ok, state, entries}
    else
      {:error, :operation_mismatch}
    end
  end

  def reserve(_state, _operation_id, _count), do: {:error, :pending_operation}

  @spec release(session_state(), term()) :: session_state()
  def release(
        %{
          game_state:
            %{
              pending_spirit_sphere_action: %{operation_id: operation_id}
            } = game_state
        } = state,
        operation_id
      ) do
    {spheres, _entries} = SpiritSpheres.release(game_state.spirit_spheres, operation_id)

    game_state =
      %{game_state | spirit_spheres: spheres, pending_spirit_sphere_action: nil}

    StateCommit.commit(state, game_state)
  end

  def release(state, _stale_operation_id), do: state

  @spec consume_reserved(session_state(), term()) ::
          {:ok, session_state()}
          | {:error, :stale_operation}
          | {:error, :reservation_changed, session_state()}
  def consume_reserved(
        %{
          game_state:
            %{
              pending_spirit_sphere_action: %{
                operation_id: operation_id,
                entry_ids: expected_entry_ids
              }
            } = game_state
        } = state,
        operation_id
      ) do
    case SpiritSpheres.consume_reserved(
           game_state.spirit_spheres,
           operation_id,
           expected_entry_ids
         ) do
      {:ok, spheres, _entries} ->
        state = put_in(state.game_state.pending_spirit_sphere_action, nil)
        {:ok, commit(state, spheres, System.monotonic_time(:millisecond), true)}

      {:error, reason} when reason in [:not_reserved, :reservation_changed] ->
        {:error, :reservation_changed, release(state, operation_id)}
    end
  end

  def consume_reserved(_state, _stale_operation_id), do: {:error, :stale_operation}

  @spec expire(session_state(), non_neg_integer()) :: {:noreply, session_state()}
  def expire(%{game_state: %{spirit_sphere_timer_generation: generation}} = state, generation) do
    now = System.monotonic_time(:millisecond)
    {spheres, expired} = SpiritSpheres.expire_due(state.game_state.spirit_spheres, now)
    {state, spheres} = invalidate_expired_reservation(state, spheres, expired)
    {:noreply, commit(state, spheres, now, expired != [])}
  end

  def expire(state, _stale_generation), do: {:noreply, state}

  @spec clear(session_state()) :: session_state()
  def clear(%{game_state: game_state} = state) do
    {spheres, cleared} = SpiritSpheres.clear(game_state.spirit_spheres)
    state = put_in(state.game_state.pending_spirit_sphere_action, nil)
    commit(state, spheres, System.monotonic_time(:millisecond), cleared != [])
  end

  @spec discard(session_state()) :: session_state()
  def discard(%{game_state: game_state} = state) do
    cancel_timer(game_state.spirit_sphere_timer)

    game_state =
      %{
        game_state
        | spirit_spheres: SpiritSpheres.new(),
          spirit_sphere_timer: nil,
          spirit_sphere_timer_generation: game_state.spirit_sphere_timer_generation + 1,
          pending_spirit_sphere_action: nil
      }

    %{state | game_state: game_state}
  end

  defp commit(%{game_state: game_state} = state, spheres, now, notify?) do
    generation = game_state.spirit_sphere_timer_generation + 1
    cancel_timer(game_state.spirit_sphere_timer)
    timer_ref = schedule_next(spheres, generation, now)

    game_state = %{
      game_state
      | spirit_spheres: spheres,
        spirit_sphere_timer: timer_ref,
        spirit_sphere_timer_generation: generation,
        spirit_sphere_revision:
          if(notify?,
            do: game_state.spirit_sphere_revision + 1,
            else: game_state.spirit_sphere_revision
          )
    }

    state = StateCommit.commit(state, game_state)
    if notify?, do: broadcast(state)
    state
  end

  defp schedule_next(spheres, generation, now) do
    case SpiritSpheres.next_expiry(spheres) do
      nil ->
        nil

      expires_at ->
        Process.send_after(self(), {:spirit_sphere_expire, generation}, max(expires_at - now, 0))
    end
  end

  defp invalidate_expired_reservation(
         %{
           game_state: %{
             pending_spirit_sphere_action: %{
               operation_id: operation_id,
               entry_ids: expected_entry_ids
             }
           }
         } = state,
         spheres,
         expired
       ) do
    if Enum.any?(expired, &(&1.id in expected_entry_ids)) do
      {spheres, _released} = SpiritSpheres.release(spheres, operation_id)
      {put_in(state.game_state.pending_spirit_sphere_action, nil), spheres}
    else
      {state, spheres}
    end
  end

  defp invalidate_expired_reservation(state, spheres, _expired), do: {state, spheres}

  defp cancel_timer(nil), do: :ok

  defp cancel_timer(timer_ref) when is_reference(timer_ref) do
    Process.cancel_timer(timer_ref)
    :ok
  end

  defp broadcast(%{connection_pid: connection_pid, game_state: game_state}) do
    update = %SpiritSphereUpdate{
      unit_id: game_state.character_id,
      count: SpiritSpheres.count(game_state.spirit_spheres),
      revision: game_state.spirit_sphere_revision
    }

    MessageRouter.send_to(connection_pid, update)
    Broadcast.to_visible_players(game_state, update, exclude_id: game_state.character_id)
  end
end
