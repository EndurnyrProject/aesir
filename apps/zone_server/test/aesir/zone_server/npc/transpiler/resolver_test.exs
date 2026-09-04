defmodule Aesir.ZoneServer.Npc.Transpiler.ResolverTest do
  @moduledoc "Covers the equip/item buildin constants added with the equip-read batch."
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler.Resolver

  describe "date constants" do
    test "resolve selectors, months, and weekdays to integer source" do
      assert Resolver.constant("DT_YYYYMMDD") == {:ok, "9"}
      assert Resolver.constant("JANUARY") == {:ok, "1"}
      assert Resolver.constant("DECEMBER") == {:ok, "12"}
      assert Resolver.constant("SUNDAY") == {:ok, "0"}
      assert Resolver.constant("SATURDAY") == {:ok, "6"}
    end

    test "unknown constants retain the existing fallback behavior" do
      assert Resolver.constant("DT_NOPE") == :error
      assert Resolver.constant("NOT_A_CONSTANT") == :error
    end
  end

  describe "refine cost constants" do
    test "resolve REFINE_COST_* to cost-type atoms" do
      assert Resolver.constant("REFINE_COST_NORMAL") == {:ok, ":normal"}
      assert Resolver.constant("REFINE_COST_HD") == {:ok, ":hd"}
      assert Resolver.constant("REFINE_COST_ENRICHED") == {:ok, ":enriched"}
    end

    test "resolve the getequiprefinecost info selectors to atoms" do
      assert Resolver.constant("REFINE_MATERIAL_ID") == {:ok, ":material_id"}
      assert Resolver.constant("REFINE_ZENY_COST") == {:ok, ":zeny_cost"}
    end
  end

  describe "ITEMINFO_* constants" do
    test "resolve to their enum ordinals" do
      assert Resolver.constant("ITEMINFO_BUY") == {:ok, "0"}
      assert Resolver.constant("ITEMINFO_TYPE") == {:ok, "2"}
      assert Resolver.constant("ITEMINFO_WEIGHT") == {:ok, "6"}
      assert Resolver.constant("ITEMINFO_WEAPONLEVEL") == {:ok, "13"}
      assert Resolver.constant("ITEMINFO_AEGISNAME") == {:ok, "18"}
      assert Resolver.constant("ITEMINFO_ARMORLEVEL") == {:ok, "19"}
      assert Resolver.constant("ITEMINFO_SUBTYPE") == {:ok, "20"}
    end
  end

  describe "W_* weapon-type constants" do
    test "resolve to their weapon-type ordinals" do
      assert Resolver.constant("W_FIST") == {:ok, "0"}
      assert Resolver.constant("W_DAGGER") == {:ok, "1"}
      assert Resolver.constant("W_1HSWORD") == {:ok, "2"}
      assert Resolver.constant("W_2HSTAFF") == {:ok, "23"}
    end
  end

  describe "cell_* constants" do
    test "resolve to trait atoms case-insensitively" do
      assert Resolver.cell_type("cell_icewall") == {:ok, :icewall}
      assert Resolver.cell_type("CELL_ICEWALL") == {:ok, :icewall}
      assert Resolver.cell_type("CELL_WALKABLE") == {:ok, :walkable}
      assert Resolver.cell_type("cell_shootable") == {:ok, :shootable}
      assert Resolver.cell_type("cell_basilica") == {:ok, :basilica}
      assert Resolver.cell_type("cell_nobuyingstore") == {:ok, :nobuyingstore}
    end

    test "returns :error for unknown strings" do
      assert Resolver.cell_type("cell_unknown") == :error
      assert Resolver.cell_type("nope") == :error
    end
  end

  describe "EAJ_*/EAJL_* constants" do
    test "resolve job-system flags, masks and job mapids to integer literals" do
      assert Resolver.constant("EAJL_2") == {:ok, "768"}
      assert Resolver.constant("EAJL_THIRD") == {:ok, "4096"}
      assert Resolver.constant("EAJL_UPPER") == {:ok, "1048576"}
      assert Resolver.constant("EAJ_THIRDMASK") == {:ok, "65535"}
      assert Resolver.constant("EAJ_RUNE_KNIGHT") == {:ok, "4353"}
      assert Resolver.constant("EAJ_KAGEROUOBORO") == {:ok, "265"}
      assert Resolver.constant("EAJ_SUPERNOVICE") == {:ok, "256"}
    end

    test "returns :error for unknown job constants" do
      assert Resolver.constant("EAJ_NOPE") == :error
    end
  end
end
