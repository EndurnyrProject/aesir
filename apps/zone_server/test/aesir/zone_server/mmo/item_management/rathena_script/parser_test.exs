defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.ParserTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Lexer
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Parser

  defp parse!(source) do
    {:ok, tokens} = Lexer.tokenize(source)
    Parser.parse(tokens)
  end

  describe "command-call statements" do
    test "parses a bare comma-separated call terminated by ;" do
      assert {:ok, [{:call, "itemheal", [45, 0]}]} = parse!("itemheal 45,0;")
    end

    test "handles unary minus on integer literals" do
      assert {:ok, [{:call, "itemheal", [-45, 0]}]} = parse!("itemheal -45,0;")
    end

    test "parses a call with no arguments" do
      assert {:ok, [{:call, "heal", []}]} = parse!("heal;")
    end

    test "classifies an rAthena constant argument as :const" do
      assert {:ok, [{:call, "sc_start", [{:const, "SC_BLESSING"}, 60_000, 10]}]} =
               parse!("sc_start SC_BLESSING,60000,10;")
    end

    test "parses a call_expr argument (rand)" do
      assert {:ok, [{:call, "itemheal", [{:call_expr, "rand", [45, 65]}, 0]}]} =
               parse!("itemheal rand(45,65),0;")
    end

    test "parses a string-literal argument" do
      assert {:ok, [{:call, "warp", ["prontera", 100, 200]}]} =
               parse!(~s(warp "prontera",100,200;))
    end

    test "parses multiple statements" do
      assert {:ok, [{:call, "itemheal", [10, 0]}, {:call, "itemheal", [20, 0]}]} =
               parse!("itemheal 10,0; itemheal 20,0;")
    end
  end

  describe "if / else" do
    test "parses if with else, both single-statement branches" do
      assert {:ok,
              [
                {:if, {:binop, :>, {:read, "BaseLevel"}, 70}, [{:call, "itemheal", [100, 0]}],
                 [{:call, "itemheal", [50, 0]}]}
              ]} = parse!("if (BaseLevel > 70) itemheal 100,0; else itemheal 50,0;")
    end

    test "parses if without else as an empty else branch" do
      assert {:ok, [{:if, {:binop, :==, {:read, "Sex"}, 1}, [{:call, "itemheal", [10, 0]}], []}]} =
               parse!("if (Sex == 1) itemheal 10,0;")
    end

    test "parses a brace-block branch into a statement list" do
      assert {:ok,
              [
                {:if, {:binop, :==, {:read, "Sex"}, 1},
                 [{:call, "itemheal", [10, 0]}, {:call, "itemheal", [20, 0]}], []}
              ]} = parse!("if (Sex == 1) { itemheal 10,0; itemheal 20,0; }")
    end
  end

  describe "expression precedence" do
    test "multiplicative binds tighter than additive, both tighter than comparison and logical" do
      assert {:ok,
              [
                {:if,
                 {:logic, :&&, {:binop, :>, {:binop, :+, 1, {:binop, :*, 2, 3}}, 5},
                  {:binop, :==, {:read, "BaseLevel"}, 70}}, [{:call, "itemheal", [1, 0]}], []}
              ]} = parse!("if (1 + 2 * 3 > 5 && BaseLevel == 70) itemheal 1,0;")
    end

    test "parentheses override precedence" do
      assert {:ok, [{:call, "itemheal", [{:binop, :*, {:binop, :+, 1, 2}, 3}, 0]}]} =
               parse!("itemheal (1 + 2) * 3,0;")
    end
  end

  describe "errors" do
    test "missing terminating semicolon returns a parse_error" do
      assert {:error, {:parse_error, _}} = parse!("itemheal 45,0")
    end

    test "a stray operator token returns a parse_error (no raise)" do
      assert {:error, {:parse_error, _}} = Parser.parse([{:op, :+}])
    end

    test "leftover tokens after a complete statement return a parse_error" do
      assert {:error, {:parse_error, _}} = Parser.parse([{:punct, :rparen}])
    end
  end
end
