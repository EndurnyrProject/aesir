defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.MovementHandler do
  @moduledoc """
  Executes Homunculus paths and separation recovery in the owner aggregate.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @movement_interval 200
  @separation_delay 3_000
  @adjacent_offsets [{0, -1}, {-1, 0}, {1, 0}, {0, 1}, {-1, -1}, {1, -1}, {-1, 1}, {1, 1}]

  @doc "Starts an explicit path to one traversable cell on the current map."
  @spec move_to(SessionState.t(), {integer(), integer()}) :: SessionState.t()
  def move_to(%SessionState{} = session, destination) do
    session = CastingHandler.cancel(session)

    case path(session, destination) do
      {:ok, cells} -> start_path(session, cells, nil, false)
      {:error, _reason} -> stop(session, true)
    end
  end

  @doc "Leaves standby and paths to a deterministic traversable cell beside the owner."
  @spec follow(SessionState.t()) :: SessionState.t()
  def follow(%SessionState{} = session) do
    session = CastingHandler.cancel(session)

    case owner_adjacent_cell(session) do
      nil ->
        stop(session, true)

      destination ->
        case path(session, destination) do
          {:ok, cells} -> start_path(session, cells, nil, false)
          {:error, _reason} -> stop(session, true)
        end
    end
  end

  @doc "Stops movement, casting, and targeting until another explicit action clears standby."
  @spec standby(SessionState.t()) :: SessionState.t()
  def standby(%SessionState{} = session) do
    session
    |> CastingHandler.cancel()
    |> stop(true)
    |> put_standby(true)
  end

  @doc "Paths toward a live typed target and stops within attack range."
  @spec chase(SessionState.t(), Unit.Ref.t()) :: SessionState.t()
  def chase(%SessionState{} = session, target_ref) do
    with %HomunculusState{} = homunculus <- session.homunculus,
         {:ok, {target_x, target_y, target_map}} <- target_position(target_ref),
         true <- target_map == homunculus.map_name,
         true <-
           distance({homunculus.x, homunculus.y}, {target_x, target_y}) > homunculus.attack_range,
         destination when not is_nil(destination) <-
           adjacent_to_target(homunculus, {target_x, target_y}),
         {:ok, cells} <- path(session, destination) do
      start_path(session, cells, target_ref, false)
    else
      false -> stop(session, false)
      _invalid -> stop(session, true)
    end
  end

  @doc "Consumes exactly one matching movement timer and advances at most one cell."
  @spec tick(reference(), SessionState.t()) :: SessionState.t()
  def tick(ref, %SessionState{} = session) do
    if session.homunculus_runtime.movement_timer_ref == ref do
      runtime = %{session.homunculus_runtime | movement_timer_ref: nil}
      session = %{session | homunculus_runtime: runtime}
      tick_current(session)
    else
      session
    end
  end

  @doc "Arms or cancels the singleton separation timer from current owner distance."
  @spec sync_separation(SessionState.t()) :: SessionState.t()
  def sync_separation(%SessionState{} = session) do
    if separated?(session) do
      arm_separation(session)
    else
      cancel_separation(session)
    end
  end

  @doc "Revalidates a matching separation timeout before deterministic relocation."
  @spec separation_timeout(reference(), SessionState.t()) :: SessionState.t()
  def separation_timeout(ref, %SessionState{} = session) do
    if session.homunculus_runtime.separation_timer_ref == ref do
      runtime = %{session.homunculus_runtime | separation_timer_ref: nil}
      session = %{session | homunculus_runtime: runtime}
      if separated?(session), do: relocate(session), else: session
    else
      session
    end
  end

  @doc "Cancels all movement-owned timers and path bookkeeping."
  @spec cancel(SessionState.t()) :: SessionState.t()
  def cancel(%SessionState{} = session) do
    runtime = session.homunculus_runtime
    Clock.cancel(runtime.movement_timer_ref)
    Clock.cancel(runtime.separation_timer_ref)

    %{
      session
      | homunculus_runtime: %{
          runtime
          | movement_timer_ref: nil,
            separation_timer_ref: nil,
            movement_path: []
        }
    }
  end

  defp tick_current(%SessionState{} = session) do
    if match?(%HomunculusState{}, session.homunculus) and
         HomunculusState.living?(session.homunculus) do
      session
      |> refresh_chase()
      |> take_step()
      |> sync_separation()
    else
      stop(session, true)
    end
  end

  defp refresh_chase(%SessionState{} = session) do
    target = session.homunculus.target

    if is_tuple(target), do: refresh_typed_chase(session, target), else: session
  end

  defp refresh_typed_chase(session, target) do
    case target_position(target) do
      {:ok, {x, y, map}} when map == session.homunculus.map_name ->
        if distance({session.homunculus.x, session.homunculus.y}, {x, y}) <=
             session.homunculus.attack_range,
           do: stop(session, false),
           else: session

      _missing ->
        stop(session, true)
    end
  end

  defp take_step(%SessionState{homunculus_runtime: %{movement_path: []}} = session),
    do: stop(session, false)

  defp take_step(%SessionState{} = session) do
    [next | rest] = session.homunculus_runtime.movement_path
    homunculus = session.homunculus
    current = {homunculus.x, homunculus.y}

    if Cell.step_traversable?(homunculus.map_name, current, next) do
      runtime = %{session.homunculus_runtime | movement_path: rest}
      moving? = rest != []

      updated = %{
        homunculus
        | x: elem(next, 0),
          y: elem(next, 1),
          action_state: if(moving?, do: :moving, else: :idle),
          movement_state: if(moving?, do: :moving, else: :standing)
      }

      session = session |> Map.put(:homunculus_runtime, runtime) |> StateCommit.commit(updated)
      if moving?, do: arm_movement(session), else: session
    else
      repath_once(session)
    end
  end

  defp repath_once(%SessionState{homunculus_runtime: %{movement_path: path}} = session) do
    case List.last(path) do
      nil ->
        stop(session, false)

      destination ->
        case path(session, destination) do
          {:ok, []} -> stop(session, false)
          {:ok, cells} -> start_path(session, cells, session.homunculus.target, false)
          {:error, _reason} -> stop(session, true)
        end
    end
  end

  defp start_path(session, [], target, standby?) do
    session
    |> stop(is_nil(target))
    |> put_target(target)
    |> put_standby(standby?)
  end

  defp start_path(session, cells, target, standby?) do
    session = cancel_movement(session)
    runtime = %{session.homunculus_runtime | movement_path: cells}

    homunculus = %{
      session.homunculus
      | action_state: :moving,
        movement_state: :moving,
        target: target,
        standby?: standby?
    }

    session
    |> Map.put(:homunculus_runtime, runtime)
    |> StateCommit.commit(homunculus)
    |> arm_movement()
  end

  defp stop(session, clear_target?) do
    session = cancel_movement(session)

    case session.homunculus do
      %HomunculusState{} = homunculus ->
        target = if clear_target?, do: nil, else: homunculus.target

        StateCommit.commit(session, %{
          homunculus
          | action_state: :idle,
            movement_state: :standing,
            target: target
        })

      nil ->
        session
    end
  end

  defp put_target(%SessionState{} = session, target) do
    case session.homunculus do
      %HomunculusState{} = homunculus ->
        StateCommit.commit(session, %{homunculus | target: target})

      nil ->
        session
    end
  end

  defp put_standby(%SessionState{} = session, value) do
    case session.homunculus do
      %HomunculusState{} = homunculus ->
        StateCommit.commit(session, %{homunculus | standby?: value})

      nil ->
        session
    end
  end

  defp cancel_movement(session) do
    Clock.cancel(session.homunculus_runtime.movement_timer_ref)

    runtime = %{
      session.homunculus_runtime
      | movement_timer_ref: nil,
        movement_path: []
    }

    %{session | homunculus_runtime: runtime}
  end

  defp arm_movement(session) do
    ref = :erlang.start_timer(@movement_interval, self(), {:homunculus, :movement_tick})
    runtime = %{session.homunculus_runtime | movement_timer_ref: ref}
    %{session | homunculus_runtime: runtime}
  end

  defp arm_separation(%SessionState{homunculus_runtime: %{separation_timer_ref: ref}} = session)
       when is_reference(ref),
       do: session

  defp arm_separation(session) do
    ref = :erlang.start_timer(@separation_delay, self(), {:homunculus, :separation_timeout})
    %{session | homunculus_runtime: %{session.homunculus_runtime | separation_timer_ref: ref}}
  end

  defp cancel_separation(session) do
    Clock.cancel(session.homunculus_runtime.separation_timer_ref)
    %{session | homunculus_runtime: %{session.homunculus_runtime | separation_timer_ref: nil}}
  end

  @doc "Relocates to the first deterministic traversable owner-adjacent cell."
  @spec relocate(SessionState.t()) :: SessionState.t()
  def relocate(%SessionState{} = session) do
    case owner_adjacent_cell(session) do
      nil ->
        session

      {x, y} ->
        session = cancel_movement(session)

        homunculus = %{
          session.homunculus
          | x: x,
            y: y,
            action_state: :idle,
            movement_state: :standing,
            target: nil
        }

        StateCommit.commit(session, homunculus)
    end
  end

  defp path(%SessionState{} = session, {x, y}) when is_integer(x) and is_integer(y) do
    homunculus = session.homunculus

    with true <- match?(%HomunculusState{}, homunculus),
         true <- HomunculusState.living?(homunculus),
         {:ok, map} <- MapCache.get(homunculus.map_name),
         true <- x >= 0 and y >= 0 and x < map.xs and y < map.ys,
         true <- Cell.traversable?(homunculus.map_name, x, y),
         {:ok, cells} <- Pathfinding.find_path(map, {homunculus.x, homunculus.y}, {x, y}) do
      {:ok, cells}
    else
      false -> {:error, :invalid_destination}
      {:error, reason} -> {:error, reason}
    end
  end

  defp path(_session, _destination), do: {:error, :invalid_destination}

  defp target_position({type, id}) do
    with {:ok, {_module, state, _pid}} <- UnitRegistry.get_unit(type, id),
         true <- Unit.living?(state),
         {:ok, {x, y, map}} <- SpatialIndex.get_unit_position(type, id) do
      {:ok, {x, y, map}}
    else
      _invalid -> {:error, :target_unavailable}
    end
  end

  defp adjacent_to_target(homunculus, target) do
    @adjacent_offsets
    |> Enum.map(fn {dx, dy} -> {elem(target, 0) + dx, elem(target, 1) + dy} end)
    |> Enum.filter(fn {x, y} -> Cell.traversable?(homunculus.map_name, x, y) end)
    |> Enum.min_by(&distance({homunculus.x, homunculus.y}, &1), fn -> nil end)
  end

  defp owner_adjacent_cell(%SessionState{} = session) do
    owner = session.game_state
    homunculus = session.homunculus

    if match?(%HomunculusState{}, homunculus) and HomunculusState.living?(homunculus) and
         owner.map_name == homunculus.map_name do
      Enum.find_value(@adjacent_offsets, &traversable_owner_adjacent(owner, &1))
    end
  end

  defp traversable_owner_adjacent(owner, {dx, dy}) do
    cell = {owner.x + dx, owner.y + dy}
    if Cell.traversable?(owner.map_name, elem(cell, 0), elem(cell, 1)), do: cell
  end

  defp separated?(%SessionState{} = session) do
    owner = session.game_state
    homunculus = session.homunculus

    match?(%HomunculusState{}, homunculus) and HomunculusState.living?(homunculus) and
      owner.map_name == homunculus.map_name and
      distance({owner.x, owner.y}, {homunculus.x, homunculus.y}) > Config.view_range()
  end

  defp distance({x1, y1}, {x2, y2}), do: max(abs(x1 - x2), abs(y1 - y2))
end
