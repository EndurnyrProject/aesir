defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.CastlingHandler do
  @moduledoc """
  Executes the Castling position swap between the owner and their Homunculus.

  Validates both swap endpoints, atomically swaps the registered positions,
  clears owner movement and intent state, and best-effort redirects mobs that
  were targeting the owner onto the Homunculus. Runs inside the owning player
  session process.
  """

  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler, as: PlayerMovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @redirect_limit 8
  @stale_fallback_limit 2

  @doc "Swaps owner and Homunculus positions when both endpoints are still valid."
  @spec swap(SessionState.t(), integer()) ::
          {:noreply, SessionState.t()} | {:error, :stale_castling_endpoint, SessionState.t()}
  def swap(
        %SessionState{
          game_state: %PlayerState{} = owner,
          homunculus: %HomunculusState{world_gid: gid} = homunculus
        } = session,
        gid
      ) do
    with true <- units_valid?(owner, homunculus),
         {:ok, {PlayerState, ^owner, owner_pid}} <-
           Movement.swap_ready(:player, owner.character_id),
         true <- owner_pid == self(),
         {:ok, {HomunculusState, ^homunculus, ^owner_pid}} <-
           Movement.swap_ready(:homunculus, gid) do
      swapped_owner = prepare_owner(owner, homunculus)

      swapped_homunculus = %{
        homunculus
        | x: owner.x,
          y: owner.y,
          action_state: :idle,
          movement_state: :standing,
          target: nil,
          casting: nil
      }

      case Movement.swap_positions(
             {:player, owner.character_id, swapped_owner},
             {:homunculus, gid, swapped_homunculus},
             owner.map_name
           ) do
        :ok ->
          session = MovementHandler.cancel(session)
          Clock.cancel(session.homunculus_runtime.cast_timer_ref)
          reconciled_owner = PlayerMovementHandler.handle_visibility_update(swapped_owner)
          runtime = %{session.homunculus_runtime | cast_timer_ref: nil, private_dirty: true}

          updated =
            struct(session,
              game_state: reconciled_owner,
              homunculus: swapped_homunculus,
              homunculus_runtime: runtime
            )

          redirect_mob(owner.map_name, owner.character_id, gid)
          {:noreply, updated}

        {:error, :stale_endpoint} ->
          {:error, :stale_castling_endpoint, session}
      end
    else
      _invalid -> {:error, :stale_castling_endpoint, session}
    end
  end

  defp units_valid?(owner, homunculus) do
    Unit.living?(owner) and HomunculusState.living?(homunculus) and
      owner.map_name == homunculus.map_name and is_binary(owner.map_name) and
      Enum.all?([owner.x, owner.y, homunculus.x, homunculus.y], &is_integer/1)
  end

  defp prepare_owner(owner, homunculus) do
    casting = owner.casting

    owner =
      owner
      |> PlayerState.stop_walking()
      |> PlayerState.clear_combat_intent()
      |> PlayerState.clear_pickup_intent()
      |> PlayerState.clear_pending_forced_movement()

    owner = if is_nil(casting), do: PlayerState.clear_skill_intent(owner), else: owner

    Map.merge(owner, %{
      x: homunculus.x,
      y: homunculus.y,
      action_state: if(is_nil(casting), do: :idle, else: owner.action_state),
      casting: casting
    })
  end

  defp redirect_mob(map_name, owner_id, homunculus_gid) do
    expected = {:player, owner_id}
    replacement = {:homunculus, homunculus_gid}

    map_name
    |> redirect_candidates(expected)
    |> Enum.reduce_while(:not_redirected, fn mob_id, _acc ->
      redirect_candidate(mob_id, expected, replacement)
    end)
  end

  defp redirect_candidates(map_name, expected) do
    map_ids = :mob |> SpatialIndex.get_units_on_map(map_name) |> Enum.sort()

    {targeting_owner, stale_fallback} =
      Enum.split_with(map_ids, fn mob_id -> mob_targets?(mob_id, expected) end)

    (targeting_owner ++ Enum.take(stale_fallback, @stale_fallback_limit))
    |> Enum.uniq()
    |> Enum.take(@redirect_limit)
  end

  defp mob_targets?(mob_id, expected) do
    match?({:ok, {_module, %{target_ref: ^expected}, _pid}}, UnitRegistry.get_unit(:mob, mob_id))
  end

  defp redirect_candidate(mob_id, expected, replacement) do
    case live_mob_pid(mob_id) do
      {:ok, pid} ->
        case MobSession.redirect_target(pid, expected, replacement) do
          :ok -> {:halt, :ok}
          {:error, :outcome_unknown} -> {:halt, :outcome_unknown}
          {:error, _definitive} -> {:cont, :not_redirected}
        end

      _unavailable ->
        {:cont, :not_redirected}
    end
  end

  defp live_mob_pid(mob_id) do
    case UnitRegistry.get_unit(:mob, mob_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) and pid != self() ->
        if Process.alive?(pid), do: {:ok, pid}, else: :error

      _other ->
        :error
    end
  end
end
