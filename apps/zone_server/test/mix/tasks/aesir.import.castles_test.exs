defmodule Mix.Tasks.Aesir.Import.CastlesTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Aesir.Import.Castles

  @fe [
    {0, "aldeg_cas01", "Neuschwanstein", 6, 212, 175},
    {1, "aldeg_cas02", "Hohenschwangau", 7, 82, 71},
    {2, "aldeg_cas03", "Nuernberg", 8, 109, 112},
    {3, "aldeg_cas04", "Wuerzburg", 9, 60, 116},
    {4, "aldeg_cas05", "Rothenburg", 10, 61, 185},
    {5, "gefg_cas01", "Repherion", 11, 40, 43},
    {6, "gefg_cas02", "Eeyolbriggar", 12, 22, 66},
    {7, "gefg_cas03", "Yesnelph", 13, 112, 23},
    {8, "gefg_cas04", "Bergel", 14, 58, 46},
    {9, "gefg_cas05", "Mersetzdeitz", 15, 66, 48},
    {10, "payg_cas01", "Bright Arbor", 16, 115, 57},
    {11, "payg_cas02", "Scarlet Palace", 17, 26, 265},
    {12, "payg_cas03", "Holy Shadow", 18, 43, 264},
    {13, "payg_cas04", "Sacred Altar", 19, 36, 272},
    {14, "payg_cas05", "Bamboo Grove Hill", 20, 274, 246},
    {15, "prtg_cas01", "Kriemhild", 1, 107, 180},
    {16, "prtg_cas02", "Swanhild", 2, 94, 56},
    {17, "prtg_cas03", "Fadhgridh", 3, 46, 97},
    {18, "prtg_cas04", "Skoegul", 4, 260, 262},
    {19, "prtg_cas05", "Gondul", 5, 26, 38}
  ]

  @fixture Enum.map(@fe, fn {id, map, name, client_id, x, y} ->
             %{
               "Id" => id,
               "Map" => map,
               "Name" => name,
               "Type" => "First_Edition",
               "ClientId" => client_id,
               "WarpX" => x,
               "WarpY" => y
             }
           end) ++
             [
               # First_Edition but not a FE castle (no warp coords, no emperium seed)
               %{
                 "Id" => 20,
                 "Map" => "nguild_alde",
                 "Name" => "Earth",
                 "Type" => "First_Edition"
               },
               # Second_Edition castle
               %{
                 "Id" => 24,
                 "Map" => "schg_cas01",
                 "Name" => "Himinn",
                 "Type" => "Second_Edition",
                 "ClientId" => 26,
                 "WarpX" => 233,
                 "WarpY" => 300
               }
             ]

  describe "build/1" do
    test "keeps exactly the 20 First-Edition castles" do
      rows = Castles.build(@fixture)

      assert length(rows) == 20
      assert Enum.map(rows, & &1.map) == Enum.map(@fe, fn {_, map, _, _, _, _} -> map end)
    end

    test "every row carries id/map/name/client_id/respawn/emperium with positive integer coordinates" do
      Enum.each(Castles.build(@fixture), fn row ->
        assert %{
                 id: id,
                 map: map,
                 name: name,
                 client_id: client_id,
                 respawn: [respawn_x, respawn_y],
                 emperium: [emperium_x, emperium_y]
               } = row

        assert is_integer(id) and id >= 0
        assert is_binary(map) and map != ""
        assert is_binary(name) and name != ""
        assert is_integer(client_id) and client_id >= 0
        assert is_integer(respawn_x) and respawn_x > 0
        assert is_integer(respawn_y) and respawn_y > 0
        assert is_integer(emperium_x) and emperium_x > 0
        assert is_integer(emperium_y) and emperium_y > 0
      end)
    end

    test "merges the emperium-room seed per map" do
      by_map = Castles.build(@fixture) |> Map.new(&{&1.map, &1})

      assert by_map["prtg_cas01"].emperium == [197, 197]
      assert by_map["prtg_cas01"].respawn == [107, 180]
      assert by_map["aldeg_cas01"].emperium == [216, 23]
      assert by_map["payg_cas05"].emperium == [30, 30]
    end

    test "is deterministic and sorted by id regardless of input order" do
      shuffled = @fixture |> Enum.reverse() |> Enum.shuffle()

      assert Castles.build(shuffled) == Castles.build(@fixture)
      assert Castles.build(@fixture) |> Enum.map(& &1.id) == Enum.to_list(0..19)

      assert Ymlr.document!(Castles.build(shuffled)) == Ymlr.document!(Castles.build(@fixture))
    end

    test "raises when a First-Edition castle is missing from the source" do
      incomplete = Enum.reject(@fixture, &(&1["Map"] == "prtg_cas01"))

      assert_raise Mix.Error, ~r/expected exactly 20 First-Edition castles/, fn ->
        Castles.build(incomplete)
      end
    end

    test "raises on a duplicated First-Edition row" do
      duplicated =
        @fixture ++
          [
            %{
              "Id" => 99,
              "Map" => "prtg_cas01",
              "Name" => "Duplicate",
              "Type" => "First_Edition",
              "ClientId" => 99,
              "WarpX" => 1,
              "WarpY" => 1
            }
          ]

      assert_raise Mix.Error, ~r/got 21/, fn -> Castles.build(duplicated) end
    end
  end

  describe "run/1" do
    test "raises on a missing input file without touching the output file" do
      out = Path.join([__DIR__, "..", "..", "..", "priv", "db", "castles", "fe.yml"])
      before = File.read!(out)

      assert_raise Mix.Error, ~r/missing input file/, fn ->
        Castles.run(["/nonexistent/rathena"])
      end

      assert File.read!(out) == before
    end
  end
end
