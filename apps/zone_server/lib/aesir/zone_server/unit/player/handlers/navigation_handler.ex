defmodule Aesir.ZoneServer.Unit.Player.Handlers.NavigationHandler do
  @moduledoc "Owns asynchronous navigation routing and its per-player session state."

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Navigation.PortalGraph
  alias Aesir.ZoneServer.Navigation.Route
  alias Aesir.ZoneServer.Navigation.Router
  alias Aesir.ZoneServer.Navigation.Session
  alias Aesir.ZoneServer.Navigation.Target
  alias Aesir.ZoneServer.Navigation.View
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @task_supervisor Aesir.ZoneServer.TaskSupervisor

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
    {:noreply, %{state | navigation: navigation}}
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

  @doc "Advances, completes, or re-routes navigation after a warp destination loads."
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
      {:on_leg, leg} -> materialize_leg(state, navigation, leg, next_index)
      :final -> state |> cancel(:arrived) |> elem(1)
      :off_route -> restart(state, navigation)
    end
  end

  def on_map_loaded(state), do: state

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

  defp materialize_path(%{map: map_name, exit_portal: portal_id}, origin) do
    with {:ok, portal} <- PortalGraph.fetch(portal_id),
         {:ok, path} <-
           Pathfinding.find_path(MapCache.get!(map_name), origin, {portal.x, portal.y}, []) do
      {:ok, [origin | path]}
    else
      :error -> {:error, :unreachable}
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
