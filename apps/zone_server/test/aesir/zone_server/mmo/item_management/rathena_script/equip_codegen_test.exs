defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.EquipCodegenTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.EquipCodegen
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Lexer
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Parser

  defp compile(script) do
    with {:ok, tokens} <- Lexer.tokenize(script),
         {:ok, stmts} <- Parser.parse(tokens) do
      EquipCodegen.generate(stmts)
    end
  end

  describe "generate/1 supported corpus scripts" do
    test "flat multi-key bonuses (id490160 ST_Orleans_Glove)" do
      assert {:ok, [{:bonus, :smatk, 3}, {:bonus, :spl, 2}, {:bonus, :crt, 2}]} =
               compile("bonus bSMatk,3; bonus bSpl,2; bonus bCrt,2;")
    end

    test "refine-scaled amount (id1298 Shiver_Katar)" do
      assert {:ok, [{:bonus, :critical, :refine}]} = compile("bonus bCritical,getrefine();")
    end

    test "assignment-inline idiom compiles the substituted expression" do
      assert {:ok, [{:bonus, :smatk, {:+, 1, {:div, :refine, 2}}}]} =
               compile(".@r = getrefine(); bonus bSMatk,1+(.@r/2);")
    end

    test "conditional refine gate (id2198 Lapine_Shield)" do
      assert {:ok, [{:bonus, :mdef, 10}, {:if, {:>, :refine, 7}, [{:bonus, :matk, 20}], []}]} =
               compile("bonus bMdef,10; if (getrefine()>7) bonus bMatk,20;")
    end

    test "if with else branch" do
      assert {:ok, [{:if, {:>=, :refine, 9}, [{:bonus, :res, 15}], [{:bonus, :res, 5}]}]} =
               compile("if (getrefine()>=9) bonus bRes,15; else bonus bRes,5;")
    end

    test "logical && and || conditions map to :and / :or" do
      assert {:ok, [{:if, {:and, {:>, :refine, 5}, {:<, :refine, 10}}, [{:bonus, :str, 1}], []}]} =
               compile("if (getrefine()>5 && getrefine()<10) bonus bStr,1;")

      assert {:ok, [{:if, {:or, {:==, :refine, 0}, {:>=, :refine, 7}}, [{:bonus, :agi, 1}], []}]} =
               compile("if (getrefine()==0 || getrefine()>=7) bonus bAgi,1;")
    end

    test "later assignment shadows the earlier binding" do
      assert {:ok, [{:bonus, :str, {:*, :refine, 2}}]} =
               compile(".@r = getrefine(); .@r = getrefine()*2; bonus bStr,.@r;")
    end

    test "nested refine gates" do
      script = "if (getrefine()>5) if (getrefine()>9) bonus bMatk,30;"

      assert {:ok,
              [{:if, {:>, :refine, 5}, [{:if, {:>, :refine, 9}, [{:bonus, :matk, 30}], []}], []}]} =
               compile(script)
    end

    test "assignment-only script yields an empty program" do
      assert {:ok, []} = compile(".@r = getrefine();")
    end
  end

  describe "generate/1 case-insensitive keys" do
    test "corpus casing and exported casing both resolve" do
      assert {:ok, [{:bonus, :patk, 20}]} = compile("bonus bPAtk,20;")
      assert {:ok, [{:bonus, :patk, 20}]} = compile("bonus bPatk,20;")
      assert {:ok, [{:bonus, :patk, 20}]} = compile("bonus BPATK,20;")
    end
  end

  describe "generate/1 rejections (all-or-nothing)" do
    test "bonus2 is an unsupported command" do
      assert {:error, {:unsupported, {:unsupported_command, "bonus2"}}} =
               compile("bonus2 bAddRace,RC_Brute,10;")
    end

    test "unknown bonus key" do
      assert {:error, {:unsupported, {:unknown_bonus_key, "bMaxHP"}}} =
               compile("bonus bMaxHP,100;")
    end

    test "non-refine conditional read is rejected" do
      assert {:error, {:unsupported, {:expression, {:read, "BaseLevel"}}}} =
               compile("if (BaseLevel>90) bonus bStr,10;")
    end

    test "conditional assignment is rejected" do
      assert {:error, {:unsupported, {:conditional_assignment, "x"}}} =
               compile("if (getrefine()>7) .@x = 5;")
    end

    test "unassigned variable is rejected" do
      assert {:error, {:unsupported, {:unassigned_var, "z"}}} = compile("bonus bStr,.@z;")
    end

    test "rand in an amount is rejected" do
      assert {:error, {:unsupported, {:unsupported_call, "rand"}}} =
               compile("bonus bStr,rand(1,5);")
    end

    test "the first violation aborts the whole item" do
      assert {:error, {:unsupported, {:unknown_bonus_key, "bMaxHP"}}} =
               compile("bonus bStr,5; bonus bMaxHP,100; bonus bAgi,3;")
    end

    test "bonus with a non-two-arg shape is rejected" do
      assert {:error, {:unsupported, {:bonus_shape, _}}} = compile("bonus bStr;")
    end
  end
end
