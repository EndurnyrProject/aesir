defmodule Aesir.ZoneServer.Navigation.ViewTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory
  import Mimic

  alias Aesir.Net.NavigateTo
  alias Aesir.Net.NavigationCell
  alias Aesir.Net.NavigationCoordinate
  alias Aesir.Net.NavigationLeg
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Navigation.View

  setup :set_mimic_from_context

  setup do
    stub(Cell, :traversable?, fn _map, _x, _y -> true end)
    :ok
  end

  test "builds ordered topology legs and simplifies only the current leg" do
    route =
      build(:navigation_route,
        legs: [
          build(:navigation_leg,
            map: "prontera",
            cells: [{1, 1}],
            exit_portal: "prt_to_gef",
            next_map: "geffen"
          ),
          build(:navigation_leg,
            index: 1,
            map: "geffen",
            cells: [{10, 20}, {11, 20}, {12, 20}, {13, 20}],
            exit_portal: "gef_to_moc",
            next_map: "morocc"
          ),
          build(:navigation_leg, index: 2, map: "morocc", cells: [{20, 20}], arrive: {25, 30})
        ]
      )

    session = build(:navigation_session, target: {:monster, 9_876}, flag: 73, hide_window: true)

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
    route =
      build(:navigation_route,
        legs: [
          build(:navigation_leg,
            map: "geffen",
            cells: [{10, 20}, {11, 20}, {12, 20}, {13, 20}],
            exit_portal: "gef_to_moc",
            next_map: "morocc"
          ),
          build(:navigation_leg, index: 1, map: "morocc", arrive: {25, 30})
        ]
      )

    session = build(:navigation_session, target: {:coord, "morocc", 25, 30})

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
    route =
      build(:navigation_route, legs: [build(:navigation_leg, map: "geffen", arrive: {5, 6})])

    session = build(:navigation_session, target: {:map, "geffen"})

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
end
