defmodule Aesir.ZoneServer.Navigation.RouteTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Navigation.Route
  alias Aesir.ZoneServer.Navigation.Route.Leg
  alias Aesir.ZoneServer.Navigation.Session

  test "returns legs by their positional index" do
    route = route(["prontera", "geffen"])

    assert {:ok, %Leg{map: "geffen"}} = Route.leg_at(route, 1)
    assert :error = Route.leg_at(route, 2)
  end

  test "identifies the current non-final leg" do
    route = route(["prontera", "geffen"])

    assert {:on_leg, %Leg{index: 0, map: "prontera"}} = Route.position(route, "prontera", 0)
  end

  test "identifies the final leg as a leg to walk rather than an arrival" do
    route = route(["prontera", "geffen"])

    assert {:on_leg, %Leg{index: 1, map: "geffen", arrive: {1, 1}}} =
             Route.position(route, "geffen", 1)
  end

  test "identifies an arrival on a map outside the current leg" do
    route = route(["prontera", "geffen"])

    assert :off_route = Route.position(route, "morocc", 0)
    assert :off_route = Route.position(route, "morocc", 1)
  end

  test "uses the supplied index when a route revisits a map" do
    route = route(["geffen", "prontera", "morocc", "izlude", "prontera"])

    assert {:on_leg, %Leg{index: 1}} = Route.position(route, "prontera", 1)
    assert {:on_leg, %Leg{index: 4}} = Route.position(route, "prontera", 4)
  end

  test "requires an epoch reference and target while defaulting route state" do
    assert_raise ArgumentError, fn -> struct!(Session, %{target: {:map, "geffen"}}) end
    assert_raise ArgumentError, fn -> struct!(Session, %{ref: make_ref()}) end

    session = %Session{ref: make_ref(), target: {:map, "geffen"}}

    assert session.route == nil
    assert session.leg == 0
  end

  defp route(maps) do
    legs =
      maps
      |> Enum.with_index()
      |> Enum.map(fn {map, index} ->
        %Leg{
          index: index,
          map: map,
          cells: nil,
          exit_portal: if(index == length(maps) - 1, do: nil, else: "portal-#{index}"),
          next_map: Enum.at(maps, index + 1),
          arrive: if(index == length(maps) - 1, do: {1, 1}, else: nil)
        }
      end)

    %Route{legs: legs}
  end
end
