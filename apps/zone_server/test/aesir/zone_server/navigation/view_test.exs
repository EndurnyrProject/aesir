defmodule Aesir.ZoneServer.Navigation.ViewTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Net.NavigateTo
  alias Aesir.Net.NavigationCell
  alias Aesir.Net.NavigationCoordinate
  alias Aesir.Net.NavigationLeg
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Navigation.Route
  alias Aesir.ZoneServer.Navigation.Route.Leg
  alias Aesir.ZoneServer.Navigation.Session
  alias Aesir.ZoneServer.Navigation.View

  setup :setup_ets_tables

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {"geffen", MapData.new("geffen", 20, 30)})
    :ok
  end

  test "builds ordered topology legs and simplifies only the current leg" do
    route = %Route{
      legs: [
        leg(0, "prontera", [{1, 1}], "prt_to_gef", "geffen", nil),
        leg(1, "geffen", [{10, 20}, {11, 20}, {12, 20}, {13, 20}], "gef_to_moc", "morocc", nil),
        leg(2, "morocc", [{20, 20}], nil, nil, {25, 30})
      ]
    }

    session = %Session{
      ref: make_ref(),
      target: {:monster, 9_876},
      flag: 73,
      hide_window: true
    }

    assert %NavigateTo{
             map: "morocc",
             x: 25,
             y: 30,
             flag: 73,
             hide_window: true,
             monster_id: 9_876,
             destination: %NavigationCoordinate{map: "morocc", x: 25, y: 30},
             legs: [
               %NavigationLeg{
                 index: 0,
                 map: "prontera",
                 cells: [],
                 exit_portal: "prt_to_gef",
                 next_map: "geffen",
                 arrive: nil
               },
               %NavigationLeg{
                 index: 1,
                 map: "geffen",
                 cells: [%NavigationCell{x: 10, y: 20}, %NavigationCell{x: 13, y: 20}],
                 exit_portal: "gef_to_moc",
                 next_map: "morocc",
                 arrive: nil
               },
               %NavigationLeg{
                 index: 2,
                 map: "morocc",
                 cells: [],
                 exit_portal: "",
                 next_map: "",
                 arrive: %NavigationCell{x: 25, y: 30}
               }
             ]
           } = View.navigate_to(route, 1, session)
  end

  test "details the first leg at index zero" do
    route = %Route{
      legs: [
        leg(
          0,
          "geffen",
          [{10, 20}, {11, 20}, {12, 20}, {13, 20}],
          "gef_to_moc",
          "morocc",
          nil
        ),
        leg(1, "morocc", nil, nil, nil, {25, 30})
      ]
    }

    session = %Session{ref: make_ref(), target: {:coord, "morocc", 25, 30}}

    assert %NavigateTo{
             legs: [
               %NavigationLeg{
                 index: 0,
                 cells: [%NavigationCell{x: 10, y: 20}, %NavigationCell{x: 13, y: 20}]
               },
               %NavigationLeg{index: 1, cells: []}
             ]
           } = View.navigate_to(route, 0, session)
  end

  test "builds a cell-less message for a single topology-only leg" do
    route = %Route{legs: [leg(0, "geffen", nil, nil, nil, {5, 6})]}
    session = %Session{ref: make_ref(), target: {:map, "geffen"}}

    assert %NavigateTo{
             map: "geffen",
             x: 5,
             y: 6,
             flag: 0,
             hide_window: false,
             monster_id: 0,
             legs: [
               %NavigationLeg{
                 index: 0,
                 map: "geffen",
                 cells: [],
                 arrive: %NavigationCell{x: 5, y: 6}
               }
             ]
           } = View.navigate_to(route, 0, session)
  end

  test "encodes each navigation failure reason distinctly" do
    assert %{reason: :NAVIGATION_FAILURE_REASON_UNRESOLVED} = View.failed(:unresolved)
    assert %{reason: :NAVIGATION_FAILURE_REASON_UNREACHABLE} = View.failed(:unreachable)
    assert %{reason: :NAVIGATION_FAILURE_REASON_ALREADY_THERE} = View.failed(:already_there)
    assert %{reason: :NAVIGATION_FAILURE_REASON_EXCLUDED} = View.failed(:excluded)
  end

  test "encodes each navigation end reason distinctly" do
    assert %{reason: :NAVIGATION_END_REASON_ARRIVED} = View.ended(:arrived)
    assert %{reason: :NAVIGATION_END_REASON_CANCELLED} = View.ended(:cancelled)
  end

  defp leg(index, map, cells, exit_portal, next_map, arrive) do
    %Leg{
      index: index,
      map: map,
      cells: cells,
      exit_portal: exit_portal,
      next_map: next_map,
      arrive: arrive
    }
  end
end
