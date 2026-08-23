defmodule Aesir.ZoneServer.Unit.Player.Handlers.NavigationHandler do
  @moduledoc "Owns asynchronous navigation routing and its per-player session state."

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Navigation.PortalGraph
  alias Aesir.ZoneServer.Navigation.Route
  alias Aesir.ZoneServer.Navigation.Route.Leg
  alias Aesir.ZoneServer.Navigation.Router
  alias Aesir.ZoneServer.Navigation.Session
  alias Aesir.ZoneServer.Navigation.Target
  alias Aesir.ZoneServer.Navigation.View
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @task_supervisor Aesir.ZoneServer.TaskSupervisor

  # A route ends when the player stands within this many cells of the final
  # leg's arrival cell, so stopping a cell short of an occupied destination -
  # or landing next to it through a warp - still counts as having arrived.
  @arrival_radius 2

  @doc "Starts an asynchronous route solve while retaining the producer's display options."
  @spec start(SessionState.t(), Target.t(), keyword()) :: {:noreply, SessionState.t()}
  def start(%SessionState{game_state: game_state} = state, target, opts \\ []) do
    ref = make_ref()

    navigation = %Session{
      ref: ref,
      target: target,
      flag: Keyword.get(opts, :flag, 0),
      hide_window: Keyword.get(opts, :hide_window, false)
    }

    session_pid = self()

    _ =
      Task.Supervisor.start_child(@task_supervisor, fn ->
        result = route(game_state, target)
        send(session_pid, {:navigation, {:routed, ref, result}})
      end)

    {:noreply, %{state | navigation: navigation}}
  end

  @doc "Ends an active navigation and notifies its client; idle cancellation is a no-op."
  @spec cancel(SessionState.t(), :cancelled | :arrived) :: {:noreply, SessionState.t()}
  def cancel(%SessionState{navigation: nil} = state, _reason), do: {:noreply, state}

  def cancel(%SessionState{} = state, reason) do
    :ok = MessageRouter.send_to(state.connection_pid, View.ended(reason))
    {:noreply, %{state | navigation: nil}}
  end

  @doc "Accepts a routing result only when its epoch still owns the active navigation."
  @spec handle_routed(SessionState.t(), reference(), {:ok, Route.t()} | {:error, atom()}) ::
          {:noreply, SessionState.t()}
  def handle_routed(
        %SessionState{navigation: %Session{ref: ref} = navigation} = state,
        ref,
        {:ok, %Route{} = route}
      ) do
    navigation = %{navigation | route: route, leg: 0}
    :ok = MessageRouter.send_to(state.connection_pid, View.navigate_to(route, 0, navigation))

    # A single-leg route to a cell the player already stands on is drawn once
    # and then ends immediately, rather than lingering until a cancel.
    {:noreply, on_moved(%{state | navigation: navigation})}
  end

  def handle_routed(
        %SessionState{navigation: %Session{ref: ref}} = state,
        ref,
        {:error, reason}
      ) do
    :ok = MessageRouter.send_to(state.connection_pid, View.failed(reason))
    {:noreply, %{state | navigation: nil}}
  end

  def handle_routed(%SessionState{} = state, _ref, _result), do: {:noreply, state}

  @doc """
  Advances, completes, or re-routes navigation after a warp destination loads.

  Loading the leg's map materializes that leg - including the final one, which
  is walked to its arrival cell. A map load that already lands within the
  arrival radius (any map-wide or monster target, whose arrival cell is the
  portal landing) ends the route instead.
  """
  @spec on_map_loaded(SessionState.t()) :: SessionState.t()
  def on_map_loaded(%SessionState{navigation: %Session{route: nil} = navigation} = state),
    do: restart(state, navigation)

  def on_map_loaded(
        %SessionState{
          game_state: game_state,
          navigation: %Session{route: %Route{} = route, leg: current_index} = navigation
        } = state
      ) do
    next_index = current_index + 1

    case Route.position(route, game_state.map_name, next_index) do
      {:on_leg, leg} -> advance(state, navigation, leg, next_index)
      :off_route -> restart(state, navigation)
    end
  end

  def on_map_loaded(state), do: state

  @doc """
  Ends navigation once a step brings the player onto the final leg's arrival cell.

  Off-route wandering within a map is still not reacted to; only reaching the
  destination is, since nothing else would ever end a same-map route.
  """
  @spec on_moved(SessionState.t()) :: SessionState.t()
  def on_moved(
        %SessionState{
          game_state: %PlayerState{map_name: map_name} = game_state,
          navigation: %Session{route: %Route{} = route, leg: index}
        } = state
      ) do
    case Route.leg_at(route, index) do
      {:ok, %Leg{map: ^map_name, exit_portal: nil, arrive: {_x, _y} = arrive}} ->
        finish_if_arrived(state, game_state, arrive)

      _ ->
        state
    end
  end

  def on_moved(state), do: state

  @doc "Accepts materialized cells only for the next leg of the active navigation epoch."
  @spec handle_materialized(
          SessionState.t(),
          reference(),
          non_neg_integer(),
          {:ok, [tuple()]} | {:error, atom()}
        ) :: {:noreply, SessionState.t()}
  def handle_materialized(
        %SessionState{
          navigation: %Session{ref: ref, route: %Route{} = route, leg: current_index} = navigation
        } = state,
        ref,
        index,
        {:ok, cells}
      )
      when index == current_index + 1 do
    legs = List.update_at(route.legs, index, fn leg -> %{leg | cells: cells} end)
    route = %{route | legs: legs}
    navigation = %{navigation | route: route, leg: index}
    :ok = MessageRouter.send_to(state.connection_pid, View.navigate_to(route, index, navigation))
    {:noreply, %{state | navigation: navigation}}
  end

  def handle_materialized(
        %SessionState{navigation: %Session{ref: ref, leg: current_index} = navigation} = state,
        ref,
        index,
        {:error, _reason}
      )
      when index == current_index + 1 do
    {:noreply, restart(state, navigation)}
  end

  def handle_materialized(%SessionState{} = state, _ref, _index, _result),
    do: {:noreply, state}

  defp restart(state, navigation) do
    {:noreply, state} =
      start(state, navigation.target,
        flag: navigation.flag,
        hide_window: navigation.hide_window
      )

    state
  end

  defp advance(state, navigation, %Leg{exit_portal: nil, arrive: arrive} = leg, index) do
    if arrived?(state.game_state, arrive) do
      state |> cancel(:arrived) |> elem(1)
    else
      materialize_leg(state, navigation, leg, index)
    end
  end

  defp advance(state, navigation, %Leg{} = leg, index),
    do: materialize_leg(state, navigation, leg, index)

  defp finish_if_arrived(state, game_state, arrive) do
    if arrived?(game_state, arrive) do
      state |> cancel(:arrived) |> elem(1)
    else
      state
    end
  end

  defp arrived?(%PlayerState{x: x, y: y}, {arrive_x, arrive_y}),
    do: abs(x - arrive_x) <= @arrival_radius and abs(y - arrive_y) <= @arrival_radius

  defp materialize_leg(state, navigation, leg, index) do
    session_pid = self()
    origin = {state.game_state.x, state.game_state.y}
    ref = make_ref()
    navigation = %{navigation | ref: ref}
    state = %{state | navigation: navigation}

    _ =
      Task.Supervisor.start_child(@task_supervisor, fn ->
        result = materialize_path(leg, origin)
        send(session_pid, {:navigation, {:materialized, ref, index, result}})
      end)

    state
  end

  defp materialize_path(%Leg{map: map_name, exit_portal: nil, arrive: arrive}, origin),
    do: walk_cells(map_name, origin, arrive)

  defp materialize_path(%Leg{map: map_name, exit_portal: portal_id}, origin) do
    case PortalGraph.fetch(portal_id) do
      {:ok, portal} -> walk_cells(map_name, origin, {portal.x, portal.y})
      :error -> {:error, :unreachable}
    end
  end

  defp walk_cells(map_name, origin, destination) do
    case Pathfinding.find_path(MapCache.get!(map_name), origin, destination, []) do
      {:ok, path} -> {:ok, [origin | path]}
      {:error, reason} -> {:error, reason}
    end
  end

  defp route(game_state, target) do
    with {:ok, candidates} <- Target.resolve(target, game_state) do
      Router.route(
        {game_state.map_name, game_state.x, game_state.y},
        candidates,
        walk_speed: game_state.walk_speed
      )
    end
  end
end
