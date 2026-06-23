defmodule Mix.Tasks.Aesir.Import.MapcacheTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Aesir.ZoneServer.Map.CacheLoader
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Mix.Tasks.Aesir.Import.Mapcache

  @walkable GatType.walkable()
  @wall GatType.wall()

  describe "run/1" do
    @tag :tmp_dir
    test "builds a loadable cache from a directory of .gat files", %{tmp_dir: tmp_dir} do
      gat_dir = Path.join(tmp_dir, "maps")
      out = Path.join(tmp_dir, "maps.mcache")
      File.mkdir_p!(gat_dir)

      File.write!(
        Path.join(gat_dir, "testa.gat"),
        gat([@walkable, @wall, @wall, @walkable], 2, 2)
      )

      File.write!(Path.join(gat_dir, "testb.gat"), gat([@walkable, @walkable, @walkable], 3, 1))

      capture_io(fn -> Mapcache.run([gat_dir, out]) end)

      assert {:ok, maps} = CacheLoader.load_cache(out)
      assert %{"testa" => %MapData{xs: 2, ys: 2} = a, "testb" => %MapData{xs: 3, ys: 1}} = maps
      assert MapData.walkable?(a, 0, 0)
      refute MapData.walkable?(a, 1, 0)
    end

    @tag :tmp_dir
    test "reports the number of gat files written", %{tmp_dir: tmp_dir} do
      gat_dir = Path.join(tmp_dir, "maps")
      out = Path.join(tmp_dir, "maps.mcache")
      File.mkdir_p!(gat_dir)
      File.write!(Path.join(gat_dir, "only.gat"), gat([@walkable], 1, 1))

      output = capture_io(fn -> Mapcache.run([gat_dir, out]) end)

      assert output =~ "mapcache: 1 gat files -> #{out}"
    end

    @tag :tmp_dir
    test "raises when no valid gat files are found", %{tmp_dir: tmp_dir} do
      gat_dir = Path.join(tmp_dir, "maps")
      File.mkdir_p!(gat_dir)

      assert_raise Mix.Error, fn ->
        capture_io(fn -> Mapcache.run([gat_dir, Path.join(tmp_dir, "maps.mcache")]) end)
      end
    end

    test "raises when the gat directory does not exist" do
      assert_raise Mix.Error, ~r/gat directory not found/, fn ->
        Mapcache.run(["/nonexistent/gat/dir", "/tmp/out.mcache"])
      end
    end
  end

  defp gat(cell_types, xs, ys) do
    cells =
      for type <- cell_types, into: <<>> do
        <<0.0::little-float-32, 0.0::little-float-32, 0.0::little-float-32, 0.0::little-float-32,
          type::little-32>>
      end

    <<"GRAT", 0x01, 0x01, xs::little-32, ys::little-32, cells::binary>>
  end
end
