defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.LexerTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Lexer

  describe "tokenize/1" do
    test "tokenizes a simple itemheal statement" do
      assert {:ok, tokens} = Lexer.tokenize("itemheal 45,0;")

      assert tokens == [
               {:ident, "itemheal"},
               {:int, 45},
               {:punct, :comma},
               {:int, 0},
               {:punct, :semicolon}
             ]
    end

    test "tokenizes all comparison and logical and arithmetic operators" do
      assert {:ok, tokens} = Lexer.tokenize("> < >= <= == != && || + - * /")

      assert tokens == [
               {:op, :>},
               {:op, :<},
               {:op, :>=},
               {:op, :<=},
               {:op, :==},
               {:op, :!=},
               {:op, :&&},
               {:op, :||},
               {:op, :+},
               {:op, :-},
               {:op, :*},
               {:op, :/}
             ]
    end

    test "tokenizes string literals including escaped quotes" do
      assert {:ok, [{:string, "prontera"}, {:punct, :comma}, {:int, 150}]} =
               Lexer.tokenize(~s("prontera",150))

      assert {:ok, [{:string, ~s(say "hi")}]} = Lexer.tokenize(~s("say \\"hi\\""))
    end

    test "tokenizes parentheses and braces" do
      assert {:ok, tokens} = Lexer.tokenize("(){}")

      assert tokens == [
               {:punct, :lparen},
               {:punct, :rparen},
               {:punct, :lbrace},
               {:punct, :rbrace}
             ]
    end

    test "tokenizes a multi-statement if/else block" do
      script = "if (BaseLevel > 70) { itemheal 100,0; } else { itemheal 50,0; }"

      assert {:ok, tokens} = Lexer.tokenize(script)

      assert tokens == [
               {:ident, "if"},
               {:punct, :lparen},
               {:ident, "BaseLevel"},
               {:op, :>},
               {:int, 70},
               {:punct, :rparen},
               {:punct, :lbrace},
               {:ident, "itemheal"},
               {:int, 100},
               {:punct, :comma},
               {:int, 0},
               {:punct, :semicolon},
               {:punct, :rbrace},
               {:ident, "else"},
               {:punct, :lbrace},
               {:ident, "itemheal"},
               {:int, 50},
               {:punct, :comma},
               {:int, 0},
               {:punct, :semicolon},
               {:punct, :rbrace}
             ]
    end

    test "drops // line comments and surrounding whitespace" do
      script = """
      // grant healing
      itemheal 45,0;  // restore hp
      """

      assert {:ok, tokens} = Lexer.tokenize(script)

      assert tokens == [
               {:ident, "itemheal"},
               {:int, 45},
               {:punct, :comma},
               {:int, 0},
               {:punct, :semicolon}
             ]
    end

    test "drops /* */ block comments, including unlexable content and multiple lines" do
      script = """
      /* +10 STR for 20 minutes
         see rAthena item_db */
      sc_start SC_BLESSING,60000,10; /* trailing */
      """

      assert {:ok, tokens} = Lexer.tokenize(script)

      assert tokens == [
               {:ident, "sc_start"},
               {:ident, "SC_BLESSING"},
               {:punct, :comma},
               {:int, 60_000},
               {:punct, :comma},
               {:int, 10},
               {:punct, :semicolon}
             ]
    end

    test "returns an error tuple on trailing garbage without raising" do
      assert {:error, _reason} = Lexer.tokenize("itemheal 45,0; @#$")
    end
  end
end
