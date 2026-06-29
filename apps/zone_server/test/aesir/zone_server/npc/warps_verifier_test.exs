defmodule Aesir.ZoneServer.Npc.WarpsVerifierTest do
  use ExUnit.Case, async: true
  import Mimic

  @moduletag :capture_log

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps

  setup :verify_on_exit!

  defp warp(overrides) do
    struct!(
      Warp,
      Keyword.merge(
        [id: "w", map: "prontera", to_map: "izlude", x: 1, y: 1, to_x: 1, to_y: 1],
        overrides
      )
    )
  end

  defp index(warps_by_map), do: %{by_map: warps_by_map}

  describe "sanitize/1 drops invalid warps without raising" do
    test "drops and warns when a warp's source map is not in MapCache" do
      stub(MapCache, :get, fn "prontera" -> {:error, :not_found} end)

      logs =
        capture_log(fn ->
          assert %{by_map: by_map} =
                   Warps.sanitize(index(%{"prontera" => [warp(map: "prontera")]}))

          refute Map.has_key?(by_map, "prontera")
        end)

      assert logs =~ ~r/unknown source map "prontera"/
      assert logs =~ "dropping"
    end

    test "drops and warns when a warp's destination map is not in MapCache" do
      stub(MapCache, :get, fn
        "prontera" -> {:ok, %MapData{}}
        "nowhere" -> {:error, :not_found}
      end)

      logs =
        capture_log(fn ->
          assert %{by_map: by_map} =
                   Warps.sanitize(index(%{"prontera" => [warp(to_map: "nowhere")]}))

          refute Map.has_key?(by_map, "prontera")
        end)

      assert logs =~ ~r/unknown destination map "nowhere"/
      assert logs =~ "dropping"
    end

    test "drops and warns when a warp's own cell is not walkable" do
      stub(MapCache, :get, fn _ -> {:ok, %MapData{}} end)
      stub(MapData, :walkable?, fn %MapData{}, 5, 5 -> false end)

      logs =
        capture_log(fn ->
          assert %{by_map: by_map} = Warps.sanitize(index(%{"prontera" => [warp(x: 5, y: 5)]}))
          refute Map.has_key?(by_map, "prontera")
        end)

      assert logs =~ ~r/non-walkable cell \(5, 5\)/
      assert logs =~ "dropping"
    end

    test "keeps the walkable warps on a map and only drops the invalid one" do
      stub(MapCache, :get, fn _ -> {:ok, %MapData{}} end)
      stub(MapData, :walkable?, fn %MapData{}, x, _ -> x != 9 end)

      kept = warp(id: "ok", x: 5, y: 5)
      dropped = warp(id: "bad", x: 9, y: 9)

      assert %{by_map: %{"prontera" => [%Warp{id: "ok"}]}} =
               Warps.sanitize(index(%{"prontera" => [kept, dropped]}))
    end
  end

  describe "sanitize/1 keeps valid warps, warning on soft issues" do
    test "keeps the warp but warns when its destination cell is not walkable" do
      stub(MapCache, :get, fn _ -> {:ok, %MapData{}} end)

      stub(MapData, :walkable?, fn
        %MapData{}, 1, 1 -> true
        %MapData{}, 9, 9 -> false
      end)

      logs =
        capture_log(fn ->
          assert %{by_map: %{"prontera" => [%Warp{}]}} =
                   Warps.sanitize(index(%{"prontera" => [warp(to_x: 9, to_y: 9)]}))
        end)

      assert logs =~ "destination cell (9, 9)"
      assert logs =~ "not walkable"
    end

    test "warns when two warps on the same map have intersecting trigger areas" do
      stub(MapCache, :get, fn _ -> {:ok, %MapData{}} end)
      stub(MapData, :walkable?, fn _, _, _ -> true end)

      a = warp(id: "a", x: 150, y: 20, xs: 1, ys: 1)
      b = warp(id: "b", x: 151, y: 20, xs: 1, ys: 1)

      logs =
        capture_log(fn ->
          assert %{by_map: %{"prontera" => [_ | _]}} =
                   Warps.sanitize(index(%{"prontera" => [a, b]}))
        end)

      assert logs =~ "overlapping trigger areas"
      assert logs =~ ~r/"a".*"b"|"b".*"a"/
    end

    test "does not warn when two warps on the same map do not overlap" do
      stub(MapCache, :get, fn _ -> {:ok, %MapData{}} end)
      stub(MapData, :walkable?, fn _, _, _ -> true end)

      a = warp(id: "a", x: 10, y: 10, xs: 0, ys: 0)
      b = warp(id: "b", x: 20, y: 20, xs: 0, ys: 0)

      logs =
        capture_log(fn ->
          assert %{by_map: %{"prontera" => [_, _]}} =
                   Warps.sanitize(index(%{"prontera" => [a, b]}))
        end)

      refute logs =~ "overlapping trigger areas"
    end
  end
end
