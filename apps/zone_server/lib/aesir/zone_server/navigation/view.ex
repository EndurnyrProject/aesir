defmodule Aesir.ZoneServer.Navigation.View do
  @moduledoc "Builds outbound navigation wire messages from server-side routes."

  alias Aesir.Net.NavigateTo
  alias Aesir.Net.NavigationCell
  alias Aesir.Net.NavigationCoordinate
  alias Aesir.Net.NavigationEnded
  alias Aesir.Net.NavigationFailed
  alias Aesir.Net.NavigationLeg
  alias Aesir.ZoneServer.Navigation.Route
  alias Aesir.ZoneServer.Navigation.Route.Leg
  alias Aesir.ZoneServer.Navigation.Session
  alias Aesir.ZoneServer.Pathfinding

  @doc "Builds a navigation update whose supplied route position carries detailed cells."
  @spec navigate_to(Route.t(), non_neg_integer(), Session.t()) :: NavigateTo.t()
  def navigate_to(%Route{legs: legs}, index, %Session{} = session)
      when is_integer(index) and index >= 0 do
    {map, x, y} = destination(List.last(legs))

    %NavigateTo{
      map: map,
      x: x,
      y: y,
      flag: session.flag,
      hide_window: session.hide_window,
      monster_id: monster_id(session.target),
      legs:
        legs
        |> Enum.with_index()
        |> Enum.map(fn {leg, leg_index} -> navigation_leg(leg, leg_index == index) end),
      destination: %NavigationCoordinate{map: map, x: x, y: y}
    }
  end

  @doc "Builds a navigation failure message for a route-resolution outcome."
  @spec failed(:unresolved | :unreachable | :already_there | :excluded) :: NavigationFailed.t()
  def failed(:unresolved), do: %NavigationFailed{reason: :NAVIGATION_FAILURE_REASON_UNRESOLVED}
  def failed(:unreachable), do: %NavigationFailed{reason: :NAVIGATION_FAILURE_REASON_UNREACHABLE}

  def failed(:already_there),
    do: %NavigationFailed{reason: :NAVIGATION_FAILURE_REASON_ALREADY_THERE}

  def failed(:excluded), do: %NavigationFailed{reason: :NAVIGATION_FAILURE_REASON_EXCLUDED}

  @doc "Builds a navigation-ended message for an active session outcome."
  @spec ended(:arrived | :cancelled) :: NavigationEnded.t()
  def ended(:arrived), do: %NavigationEnded{reason: :NAVIGATION_END_REASON_ARRIVED}
  def ended(:cancelled), do: %NavigationEnded{reason: :NAVIGATION_END_REASON_CANCELLED}

  defp navigation_leg(%Leg{} = leg, detailed?) do
    %NavigationLeg{
      index: leg.index,
      map: leg.map,
      cells: cells(leg, detailed?),
      exit_portal: optional_string(leg.exit_portal),
      next_map: optional_string(leg.next_map),
      arrive: navigation_cell(leg.arrive)
    }
  end

  defp cells(%Leg{cells: nil}, true), do: []

  defp cells(%Leg{cells: cells, map: map_name}, true) do
    cells
    |> Pathfinding.simplify_path(map_name)
    |> Enum.map(&navigation_cell/1)
  end

  defp cells(_leg, false), do: []

  defp destination(%Leg{map: map, arrive: {x, y}}), do: {map, x, y}

  defp monster_id({:monster, monster_id}), do: monster_id
  defp monster_id(_target), do: 0

  defp optional_string(nil), do: ""
  defp optional_string(value), do: value

  defp navigation_cell(nil), do: nil
  defp navigation_cell({x, y}), do: %NavigationCell{x: x, y: y}
end
