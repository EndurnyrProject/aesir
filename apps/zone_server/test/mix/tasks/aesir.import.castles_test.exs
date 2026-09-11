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

  @guardian_slots Map.new(@fe, fn {_id, map, _name, _client_id, _x, _y} ->
                    {map, Enum.map(1..8, &%{type: "soldier", cell: [&1, &1]})}
                  end)

  describe "build/2" do
    test "keeps exactly the 20 First-Edition castles" do
      rows = Castles.build(@fixture, @guardian_slots)

      assert length(rows) == 20
      assert Enum.map(rows, & &1.map) == Enum.map(@fe, fn {_, map, _, _, _, _} -> map end)
    end

    test "every row carries id/map/name/client_id/respawn/emperium with positive integer coordinates" do
      Enum.each(Castles.build(@fixture, @guardian_slots), fn row ->
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
      by_map = Castles.build(@fixture, @guardian_slots) |> Map.new(&{&1.map, &1})

      assert by_map["prtg_cas01"].emperium == [197, 197]
      assert by_map["prtg_cas01"].respawn == [107, 180]
      assert by_map["aldeg_cas01"].emperium == [216, 23]
      assert by_map["payg_cas05"].emperium == [30, 30]
    end

    test "merges the treasure-room seed per map" do
      by_map = Castles.build(@fixture, @guardian_slots) |> Map.new(&{&1.map, &1})

      assert %{box_id: 1354, cells: cells} = by_map["prtg_cas01"].treasure
      assert length(cells) == 24
      assert hd(cells) == [10, 209]
    end

    test "every row's treasure has a box id and exactly 24 cells" do
      Enum.each(Castles.build(@fixture, @guardian_slots), fn row ->
        assert %{box_id: box_id, cells: cells} = row.treasure
        assert is_integer(box_id) and box_id > 0
        assert length(cells) == 24

        assert Enum.all?(cells, fn
                 [x, y] -> is_integer(x) and x > 0 and is_integer(y) and y > 0
                 _other -> false
               end)
      end)
    end

    test "is deterministic and sorted by id regardless of input order" do
      shuffled = @fixture |> Enum.reverse() |> Enum.shuffle()

      assert Castles.build(shuffled, @guardian_slots) == Castles.build(@fixture, @guardian_slots)

      assert Castles.build(@fixture, @guardian_slots) |> Enum.map(& &1.id) ==
               Enum.to_list(0..19)

      assert Ymlr.document!(Castles.build(shuffled, @guardian_slots)) ==
               Ymlr.document!(Castles.build(@fixture, @guardian_slots))
    end

    test "normalizes pre-renewal respawns from reversed Renewal rows by numeric id only" do
      pre =
        Enum.map(@fixture, fn
          %{"Id" => 0} = row ->
            row |> Map.drop(["WarpX", "WarpY"]) |> Map.put("Name", "Classic Neuschwanstein")

          %{"Id" => id} = row when id in 1..19 ->
            Map.drop(row, ["WarpX", "WarpY"])

          row ->
            row
        end)

      rows =
        pre
        |> Castles.normalize_respawns!(Enum.reverse(@fixture))
        |> Castles.build(@guardian_slots)

      assert Enum.map(rows, & &1.respawn) ==
               Enum.map(@fe, fn {_id, _map, _name, _client_id, x, y} -> [x, y] end)

      assert hd(rows).name == "Classic Neuschwanstein"
      assert hd(rows).map == "aldeg_cas01"
      assert hd(rows).client_id == 6
    end

    test "raises on duplicate pre-renewal castle ids" do
      pre =
        Enum.map(@fixture, fn
          %{"Id" => id} = row when id in 0..19 -> Map.drop(row, ["WarpX", "WarpY"])
          row -> row
        end)

      assert_raise Mix.Error, ~r/duplicate pre-renewal castle id 0/, fn ->
        Castles.normalize_respawns!([hd(pre) | pre], @fixture)
      end
    end

    test "raises with missing or extra Renewal castle ids" do
      pre =
        Enum.map(@fixture, fn
          %{"Id" => id} = row when id in 0..19 -> Map.drop(row, ["WarpX", "WarpY"])
          row -> row
        end)

      assert_raise Mix.Error, ~r/Renewal castle ID mismatch: missing \[0\], extra \[\]/, fn ->
        Castles.normalize_respawns!(pre, Enum.reject(@fixture, &(&1["Id"] == 0)))
      end

      extra = update_in(@fixture, [Access.at(0), "Id"], &(&1 + 100))

      assert_raise Mix.Error, ~r/Renewal castle ID mismatch: missing \[0\], extra \[100\]/, fn ->
        Castles.normalize_respawns!(pre, extra)
      end
    end

    test "raises on duplicate or malformed Renewal respawn matches" do
      pre =
        Enum.map(@fixture, fn
          %{"Id" => id} = row when id in 0..19 -> Map.drop(row, ["WarpX", "WarpY"])
          row -> row
        end)

      assert_raise Mix.Error, ~r/duplicate Renewal castle id 0/, fn ->
        Castles.normalize_respawns!(pre, [hd(@fixture) | @fixture])
      end

      malformed = put_in(@fixture, [Access.at(0), "WarpX"], 0)

      assert_raise Mix.Error, ~r/malformed Renewal WarpX for castle id 0/, fn ->
        Castles.normalize_respawns!(pre, malformed)
      end
    end

    test "rejects complete pre-renewal respawn coordinates" do
      assert_raise Mix.Error, ~r/pre-renewal castle id 0 must not define WarpX or WarpY/, fn ->
        Castles.normalize_respawns!(@fixture, @fixture)
      end
    end

    test "rejects partial pre-renewal respawn coordinates" do
      partial = update_in(@fixture, [Access.at(0)], &Map.delete(&1, "WarpX"))

      assert_raise Mix.Error, ~r/pre-renewal castle id 0 must not define WarpX or WarpY/, fn ->
        Castles.normalize_respawns!(partial, @fixture)
      end
    end

    test "raises when a First-Edition castle is missing from the source" do
      incomplete = Enum.reject(@fixture, &(&1["Map"] == "prtg_cas01"))

      assert_raise Mix.Error, ~r/expected exactly 20 First-Edition castles/, fn ->
        Castles.build(incomplete, @guardian_slots)
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

      assert_raise Mix.Error, ~r/got 21/, fn -> Castles.build(duplicated, @guardian_slots) end
    end

    test "raises when a seed map has no slots" do
      missing_slots = Map.delete(@guardian_slots, "prtg_cas01")

      assert_raise Mix.Error, ~r/prtg_cas01/, fn ->
        Castles.build(@fixture, missing_slots)
      end
    end
  end

  describe "parse_guardian_slots!/1" do
    @manager_script """
    -\tscript\tDecoy#not_cm::decoy\t-1,{
    \tif (strnpcinfo(2) == "aldeg_cas01") {
    \t\tsetarray .@guardiantype[0],9,9,9,9,9,9,9,9;
    \t\tsetarray .@guardianposx[0],1,1,1,1,1,1,1,1;
    \t\tsetarray .@guardianposy[0],1,1,1,1,1,1,1,1;
    \t}
    }

    -\tscript\tCastle Manager#cm::cm\t-1,{

    \tset .@GID,GetCastleData(strnpcinfo(2),CD_GUILD_ID);

    \tif (strnpcinfo(2) == "aldeg_cas01") {
    \t\tsetarray .@guardiantype[0],1,2,2,2,2,3,3,3;
    \t\tsetarray .@guardianposx[0],17,39,38,45,21,218,213,73;
    \t\tsetarray .@guardianposy[0],218,208,196,228,194,24,24,70;
    \t\tsetarray .@masterroom[0],113,223;
    \t}
    \telse if (strnpcinfo(2) == "aldeg_cas02") {
    \t\tsetarray .@guardiantype[0],3,3,3,1,1,2,2,2;
    \t\tsetarray .@guardianposx[0],27,88,117,60,51,21,36,210;
    \t\tsetarray .@guardianposy[0],184,43,46,202,183,177,183,7;
    \t\tsetarray .@masterroom[0],134,225;
    \t}
    \telse {
    \t\tend;
    \t}
    }

    -\tscript\tLever#gd::gdlever\t-1,{
    \tif (strnpcinfo(2) == "aldeg_cas01") {
    \t\tsetarray .@guardiantype[0],9,9,9,9,9,9,9,9;
    \t\tsetarray .@guardianposx[0],1,1,1,1,1,1,1,1;
    \t\tsetarray .@guardianposy[0],1,1,1,1,1,1,1,1;
    \t}
    }
    """

    test "returns every castle block's slots in slot order" do
      slots = Castles.parse_guardian_slots!(@manager_script)

      assert slots["aldeg_cas01"] == [
               %{type: "soldier", cell: [17, 218]},
               %{type: "archer", cell: [39, 208]},
               %{type: "archer", cell: [38, 196]},
               %{type: "archer", cell: [45, 228]},
               %{type: "archer", cell: [21, 194]},
               %{type: "knight", cell: [218, 24]},
               %{type: "knight", cell: [213, 24]},
               %{type: "knight", cell: [73, 70]}
             ]

      assert slots["aldeg_cas02"] == [
               %{type: "knight", cell: [27, 184]},
               %{type: "knight", cell: [88, 43]},
               %{type: "knight", cell: [117, 46]},
               %{type: "soldier", cell: [60, 202]},
               %{type: "soldier", cell: [51, 183]},
               %{type: "archer", cell: [21, 177]},
               %{type: "archer", cell: [36, 183]},
               %{type: "archer", cell: [210, 7]}
             ]
    end

    test "ignores an identically shaped block outside the castle manager script" do
      slots = Castles.parse_guardian_slots!(@manager_script)

      assert hd(slots["aldeg_cas01"]) == %{type: "soldier", cell: [17, 218]}
    end

    test "raises naming the map and array when an array has fewer than eight integers" do
      malformed =
        String.replace(@manager_script, "17,39,38,45,21,218,213,73", "17,39,38,45,21,218,213")

      assert_raise Mix.Error, ~r/aldeg_cas01.*guardianposx/, fn ->
        Castles.parse_guardian_slots!(malformed)
      end
    end

    test "raises naming the map when a guardian type is out of range" do
      malformed = String.replace(@manager_script, "1,2,2,2,2,3,3,3", "4,2,2,2,2,3,3,3")

      assert_raise Mix.Error, ~r/aldeg_cas01.*guardiantype/, fn ->
        Castles.parse_guardian_slots!(malformed)
      end
    end
  end

  describe "run/1" do
    test "raises on a missing input file without touching the output file" do
      out = Path.join([__DIR__, "..", "..", "..", "priv", "db", "re", "castles", "fe.yml"])
      before = File.read!(out)

      assert_raise Mix.Error, ~r/missing rAthena YAML file/, fn ->
        Castles.run(["/nonexistent/rathena"])
      end

      assert File.read!(out) == before
    end
  end
end
