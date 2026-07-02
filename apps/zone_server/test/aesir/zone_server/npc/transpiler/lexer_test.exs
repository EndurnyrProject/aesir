defmodule Aesir.ZoneServer.Npc.Transpiler.LexerTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler.Lexer

  test "lexes every variable scope prefix, with string suffix" do
    assert {:ok, tokens} = Lexer.tokenize(".@a @b #c ##d $e $@f .g 'h .@s$ name$ name")

    assert tokens == [
             {:var, :local, "a", :int},
             {:var, :session, "b", :int},
             {:var, :account, "c", :int},
             {:var, :account_global, "d", :int},
             {:var, :server, "e", :int},
             {:var, :server_temp, "f", :int},
             {:var, :npc, "g", :int},
             {:var, :instance, "h", :int},
             {:var, :local, "s", :str},
             {:ident, "name$"},
             {:ident, "name"}
           ]
  end

  test "lexes decimal and hex integers" do
    assert {:ok, [{:int, 42}, {:int, 255}, {:int, 10_000}]} = Lexer.tokenize("42 0xFF 10000")
  end

  test "lexes strings with escapes" do
    assert {:ok, [{:string, ~s(say "hi")}]} = Lexer.tokenize(~S("say \"hi\""))
  end

  test "lexes the full operator set, longest match first" do
    assert {:ok, tokens} = Lexer.tokenize("a += 1; b <<= 2; c ? d : e; f++; g != h && i || !j")

    ops = for {:op, op} <- tokens, do: op
    assert ops == [:add_assign, :shl_assign, :question, :inc, :!=, :&&, :||, :!]

    assert {:ok, [{:op, :shl}, {:op, :<=}, {:op, :<}]} = Lexer.tokenize("<< <= <")
  end

  test "lexes a realistic statement" do
    assert {:ok, tokens} =
             Lexer.tokenize(~S|if (Zeny >= 500) { set .@ok, 1; getitem 501, .@qty[0]; }|)

    assert {:ident, "if"} = hd(tokens)
    assert {:var, :local, "qty", :int} in tokens
    assert {:punct, :lbracket} in tokens
    assert {:op, :>=} in tokens
  end

  test "unlexable input returns an error tuple" do
    assert {:error, _} = Lexer.tokenize("valid then \x01 garbage")
  end
end
