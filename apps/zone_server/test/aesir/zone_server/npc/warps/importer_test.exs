defmodule Aesir.ZoneServer.Npc.Warps.ImporterTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Warps.Importer

  describe "parse_line/1" do
    test "maps a standard warp line onto our YAML schema" do
      line = "prontera,107,215,0\twarp\tprt01\t2,2,prt_in,240,139"

      assert {:ok,
              %{
                "id" => "prt01",
                "map" => "prontera",
                "x" => 107,
                "y" => 215,
                "xs" => 2,
                "ys" => 2,
                "sprite" => 45,
                "name" => "",
                "to" => %{"map" => "prt_in", "x" => 240, "y" => 139}
              }} = Importer.parse_line(line)
    end

    test "treats warp2 as a normal warp" do
      line = "mosk_in,215,36,0\twarp2\tbabayagaout\t1,1,mosk_dun02,53,217"

      assert {:ok, %{"id" => "babayagaout", "to" => %{"map" => "mosk_dun02"}}} =
               Importer.parse_line(line)
    end

    test "accepts the warp(<STATE>) variant" do
      line = "prontera,107,215,0\twarp(HIDDEN)\tprt01\t2,2,prt_in,240,139"

      assert {:ok, %{"id" => "prt01"}} = Importer.parse_line(line)
    end

    test "tolerates space-separated columns" do
      line = "geffen,119,213,0   warp   gef001   3,2,gef_fild04,187,42"

      assert {:ok, %{"map" => "geffen", "xs" => 3, "ys" => 2}} = Importer.parse_line(line)
    end

    test "skips blank lines and comments" do
      assert :skip = Importer.parse_line("")
      assert :skip = Importer.parse_line("   ")
      assert :skip = Importer.parse_line("//===== rAthena Script =====")
    end

    test "skips non-warp NPC lines" do
      assert :skip = Importer.parse_line("prontera\tmapflag\tnopvp")
      assert :skip = Importer.parse_line("prt_fild01,0,0,0,0\tmonster\tPoring\t1002,50,0,0")
    end

    test "skips non-UTF-8 lines" do
      assert :skip = Importer.parse_line(<<0xFF, 0xFE, "warp">>)
    end

    test "skips an embedded warp script command (not a warp definition)" do
      assert :skip = Importer.parse_line("\tdefault: warp \"lhz_cube\",67,193; end;")
    end

    test "reports a warp line with non-numeric coordinates" do
      line = "prontera,107,abc,0\twarp\tprt01\t2,2,prt_in,240,139"

      assert {:error, {:malformed, _, _}} = Importer.parse_line(line)
    end

    test "reports a warp line with a missing destination field" do
      line = "prontera,107,215,0\twarp\tprt01\t2,2,prt_in,240"

      assert {:error, {:malformed, _, _}} = Importer.parse_line(line)
    end
  end
end
