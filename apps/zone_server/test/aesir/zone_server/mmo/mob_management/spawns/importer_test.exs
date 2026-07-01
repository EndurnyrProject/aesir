defmodule Aesir.ZoneServer.Mmo.MobManagement.Spawns.ImporterTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns.Importer

  describe "parse_line/1" do
    test "parses a 3-field location line with xs=0, ys=0" do
      line = "prt_fild00,0,0\tmonster\tRoda Frog\t1012,169,5000"

      assert {:ok,
              %{
                "map" => "prt_fild00",
                "spawns" => [
                  %{
                    "mob" => 1012,
                    "amount" => 169,
                    "respawn_time" => 5000,
                    "area" => %{"x" => 0, "y" => 0, "xs" => 0, "ys" => 0}
                  }
                ]
              }} = Importer.parse_line(line)
    end

    test "parses a 5-field location line with xs,ys from the line" do
      line = "prt_fild00,285,138,10,10\tmonster\tGreen Plant\t1080,5,360000,180000"

      assert {:ok,
              %{
                "map" => "prt_fild00",
                "spawns" => [
                  %{
                    "mob" => 1080,
                    "amount" => 5,
                    "respawn_time" => 360_000,
                    "area" => %{"x" => 285, "y" => 138, "xs" => 10, "ys" => 10}
                  }
                ]
              }} = Importer.parse_line(line)
    end

    test "drops trailing delay2/event/size/ai fields" do
      line =
        "lhz_dun_n,0,0\tmonster\tEremes Guille\t3208,20,5000,0,\"lhz_dun_n::OnRegularDead3208\""

      assert {:ok,
              %{
                "spawns" => [%{"mob" => 3208, "amount" => 20, "respawn_time" => 5000}]
              }} = Importer.parse_line(line)
    end

    test "parses a bare-map location as whole-map 0,0 spawn" do
      line = "for_dun01\tmonster\t--ja--\t22192,12"

      assert {:ok,
              %{
                "map" => "for_dun01",
                "spawns" => [
                  %{
                    "mob" => 22_192,
                    "amount" => 12,
                    "respawn_time" => 0,
                    "area" => %{"x" => 0, "y" => 0, "xs" => 0, "ys" => 0}
                  }
                ]
              }} = Importer.parse_line(line)
    end

    test "defaults respawn_time to 0 when delay is omitted" do
      line = "prt_fild08,0,0\tmonster\tPoring\t1002,110"

      assert {:ok, %{"spawns" => [%{"mob" => 1002, "amount" => 110, "respawn_time" => 0}]}} =
               Importer.parse_line(line)
    end

    test "strips an inline // comment before parsing" do
      line = "tra_fild01,24,36\tmonster\tDummy (Small)\t22559,1\t// S_DUMMY_SMALL_R30"

      assert {:ok,
              %{
                "spawns" => [
                  %{
                    "mob" => 22_559,
                    "amount" => 1,
                    "respawn_time" => 0,
                    "area" => %{"x" => 24, "y" => 36, "xs" => 0, "ys" => 0}
                  }
                ]
              }} = Importer.parse_line(line)
    end

    test "trims leading whitespace in the mob CSV column" do
      line = "ein_d02_i\tmonster\tRed Teddybear\t 20255,25,5000,0,\"ein_d02_i_boss::OnMobDead\""

      assert {:ok, %{"spawns" => [%{"mob" => 20_255, "amount" => 25, "respawn_time" => 5000}]}} =
               Importer.parse_line(line)
    end

    test "keeps a non-numeric mob token as a string for later resolution" do
      line = "nif_dun01\tmonster\tGan Ceann\tGAN_CEANN,60"

      assert {:ok, %{"spawns" => [%{"mob" => "GAN_CEANN", "amount" => 60, "respawn_time" => 0}]}} =
               Importer.parse_line(line)
    end

    test "skips boss_monster lines" do
      line = "gl_cas02_,0,0\tboss_monster\tBaphomet\t1039,1,7200000,0,0"

      assert :skip = Importer.parse_line(line)
    end

    test "skips blank lines and comments" do
      assert :skip = Importer.parse_line("")
      assert :skip = Importer.parse_line("   ")
      assert :skip = Importer.parse_line("//===== rAthena Script =====")
    end

    test "skips non-monster lines" do
      assert :skip = Importer.parse_line("prontera\tmapflag\tnopvp")
    end

    test "skips non-UTF-8 lines" do
      assert :skip = Importer.parse_line(<<0xFF, 0xFE, "monster">>)
    end

    test "reports a monster line with a short CSV" do
      line = "prt_fild00,0,0\tmonster\tRoda Frog\t1012"

      assert {:error, {:malformed, _, _}} = Importer.parse_line(line)
    end

    test "reports a monster line with a non-numeric amount" do
      line = "prt_fild00,0,0\tmonster\tRoda Frog\t1012,abc,5000"

      assert {:error, {:malformed, _, _}} = Importer.parse_line(line)
    end

    test "reports a monster line with a bad location arity" do
      line = "prt_fild00,0,0,10\tmonster\tRoda Frog\t1012,169,5000"

      assert {:error, {:malformed, _, _}} = Importer.parse_line(line)
    end
  end
end
