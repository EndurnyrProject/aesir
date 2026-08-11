defmodule Aesir.ZoneServer.Npc.Transpiler.ResolverTest do
  @moduledoc "Covers the equip/item buildin constants added with the equip-read batch."
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler.Resolver

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
end
