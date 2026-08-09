defmodule Aesir.ZoneServer.Npc.Shops.ImporterTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Shops.Importer

  describe "parse_line/1" do
    test "maps a real placed shop line onto our YAML schema with price -1 -> nil" do
      line = "alberta_in,165,96,0\tshop\tItem Collector#alb\t74,911:-1,528:-1"

      assert {:ok,
              %{
                "id" => "Item Collector#alb",
                "name" => "Item Collector",
                "map" => "alberta_in",
                "x" => 165,
                "y" => 96,
                "dir" => 0,
                "sprite" => 74,
                "items" => [
                  %{"id" => 911, "price" => nil},
                  %{"id" => 528, "price" => nil}
                ]
              }} = Importer.parse_line(line)
    end

    test "keeps a positive price as an explicit override" do
      line = "prontera,147,240,5\tshop\tArmor\t99,2304:10000,2306:20000"

      assert {:ok,
              %{
                "sprite" => 99,
                "items" => [
                  %{"id" => 2304, "price" => 10_000},
                  %{"id" => 2306, "price" => 20_000}
                ]
              }} = Importer.parse_line(line)
    end

    test "strips the #suffix from name but keeps the full string as id" do
      line = "alberta_in,182,97,0\tshop\tTool Dealer#alb2\t73,501:-1"

      assert {:ok, %{"id" => "Tool Dealer#alb2", "name" => "Tool Dealer"}} =
               Importer.parse_line(line)
    end

    test "falls back to the default sprite for a string-constant sprite" do
      line = "prontera,150,60,4\tshop\tHerb Seller#test\tHIDDEN_NPC,7932:4000"

      assert {:ok, %{"sprite" => 83, "items" => [%{"id" => 7932, "price" => 4000}]}} =
               Importer.parse_line(line)
    end

    test "records the optional yes/no discount token after the sprite" do
      string_sprite = "prontera,150,60,4\tshop\tRunes Seller\tHIDDEN_NPC,no,12737:1000"
      numeric_sprite = "prontera,150,60,4\tshop\tFoo\t99,yes,501:50"
      implicit = "prontera,150,60,4\tshop\tBar\t99,501:50"

      assert {:ok,
              %{
                "sprite" => 83,
                "discount" => false,
                "items" => [%{"id" => 12_737, "price" => 1000}]
              }} = Importer.parse_line(string_sprite)

      assert {:ok,
              %{"sprite" => 99, "discount" => true, "items" => [%{"id" => 501, "price" => 50}]}} =
               Importer.parse_line(numeric_sprite)

      assert {:ok, %{"discount" => true}} = Importer.parse_line(implicit)
    end

    test "returns {:duplicate, label, partial_map} for a duplicate line, with no items" do
      line = "izlude_a,124,165,4\tduplicate(Fruit Gardener#iz)\tFruit Gardener#iz_a\t53"

      assert {:duplicate, "Fruit Gardener#iz",
              %{
                "id" => "Fruit Gardener#iz_a",
                "name" => "Fruit Gardener",
                "map" => "izlude_a",
                "x" => 124,
                "y" => 165,
                "dir" => 4,
                "sprite" => 53
              } = partial} = Importer.parse_line(line)

      refute Map.has_key?(partial, "items")
    end

    test "returns {:source, :script, exname} for a script NPC (a duplicate source)" do
      assert {:source, :script, "#over_arrow"} =
               Importer.parse_line("-\tscript\t#over_arrow\tHIDDEN_NPC,{")

      assert {:source, :script, "pss"} =
               Importer.parse_line("-\tscript\t::pss\tHIDDEN_NPC,{")
    end

    test "returns {:source, :cashshop, exname} for a cashshop NPC, taking the ::exname" do
      assert {:source, :cashshop, "idRO_kafra"} =
               Importer.parse_line("-\tcashshop\tidROCK::idRO_kafra\t721,16555:1000")
    end

    test "skips a floating (-) shop line" do
      assert :skip = Importer.parse_line("-\tshop\tcard_mob#A\t-1,501:1000")
    end

    test "skips blank lines and comments" do
      assert :skip = Importer.parse_line("")
      assert :skip = Importer.parse_line("   ")
      assert :skip = Importer.parse_line("//===== rAthena Script =====")
    end

    test "skips non-shop NPC lines" do
      assert :skip = Importer.parse_line("prontera\tmapflag\tnopvp")
      assert :skip = Importer.parse_line("prt_fild01,0,0,0,0\tmonster\tPoring\t1002,50,0,0")
    end

    test "skips non-UTF-8 lines" do
      assert :skip = Importer.parse_line(<<0xFF, 0xFE, "shop">>)
    end
  end
end
