defmodule Aesir.ZoneServer.Script.RathenaTest do
  @moduledoc """
  Covers the `input` range helpers backing rAthena's `input <var>,<min>,<max>`
  return value (0 in range, 1 below/too short, 2 above/too long).
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Script.Rathena

  describe "atoi/1" do
    test "parses the leading integer of a string" do
      assert Rathena.atoi("01") == 1
      assert Rathena.atoi("42abc") == 42
      assert Rathena.atoi("  -7") == -7
      assert Rathena.atoi("+3") == 3
    end

    test "returns 0 when there are no leading digits" do
      assert Rathena.atoi("") == 0
      assert Rathena.atoi("abc") == 0
      assert Rathena.atoi(nil) == 0
    end

    test "passes integers through unchanged" do
      assert Rathena.atoi(5) == 5
    end
  end

  describe "input_int/3" do
    test "returns {0, value} when in range" do
      assert Rathena.input_int(3, 1, 5) == {0, 3}
    end

    test "clamps to min and returns status 1 when below" do
      assert Rathena.input_int(0, 1, 5) == {1, 1}
      assert Rathena.input_int(-10, 1, 5) == {1, 1}
    end

    test "clamps to max and returns status 2 when above" do
      assert Rathena.input_int(9, 1, 5) == {2, 5}
    end
  end

  describe "array helpers" do
    test "put_many/4 overwrites consecutive values without clearing the tail" do
      assert Rathena.put_many(["old", "tail", "keep"], 0, ["a", "b"], "") ==
               ["a", "b", "keep"]

      assert Rathena.put_many([], 2, ["a", "b"], "") == ["", "", "a", "b"]
    end

    test "explode/2 uses the delimiter's first grapheme and preserves empty fields" do
      assert Rathena.explode("a::b", ":ignored") == ["a", "", "b"]
      assert Rathena.explode("a🙂b🙂", "🙂x") == ["a", "b", ""]
      assert Rathena.explode("abc", "") == ["abc"]
    end
  end

  describe "delete_at/3" do
    test "removes count elements at index, shifting later values down" do
      assert Rathena.delete_at([1, 2, 3, 4, 5], 1, 2) == [1, 4, 5]
      assert Rathena.delete_at([1, 2, 3], 0, 1) == [2, 3]
    end

    test ":rest deletes everything from index to the end" do
      assert Rathena.delete_at([1, 2, 3, 4], 2, :rest) == [1, 2]
      assert Rathena.delete_at([1, 2], 0, :rest) == []
    end

    test "a count past the end just truncates" do
      assert Rathena.delete_at([1, 2, 3], 1, 99) == [1]
      assert Rathena.delete_at([], 0, 5) == []
    end
  end

  describe "input_str/3" do
    test "returns {0, string} when length is in range" do
      assert Rathena.input_str("abc", 1, 5) == {0, "abc"}
    end

    test "returns status 1 when too short (value unchanged)" do
      assert Rathena.input_str("", 1, 5) == {1, ""}
    end

    test "returns status 2 when too long (value unchanged)" do
      assert Rathena.input_str("toolong", 1, 5) == {2, "toolong"}
    end
  end

  describe "string helpers" do
    test "compare/2 performs a case-insensitive substring test" do
      assert Rathena.compare("Bloody Murderer", "blood") == 1
      assert Rathena.compare("Blood Butterfly", "bloody") == 0
    end

    test "length, indexing, alpha checks, and inclusive slices use Unicode graphemes" do
      assert Rathena.getstrlen("hé🙂") == 3
      assert Rathena.charat("hé🙂", 1) == "é"
      assert Rathena.charat("hé🙂", -1) == ""
      assert Rathena.charat("hé🙂", 3) == ""
      assert Rathena.charisalpha("é1", 0) == 1
      assert Rathena.charisalpha("é1", 1) == 0
      assert Rathena.substr("aé🙂z", 1, 2) == "é🙂"
      assert Rathena.substr("aé🙂z", 2, 1) == ""
      assert Rathena.substr("aé🙂z", 0, 4) == ""
    end

    test "case conversion uses Unicode casing" do
      assert Rathena.strtoupper("Olá!") == "OLÁ!"
      assert Rathena.strtolower("ÉLAN") == "élan"
    end

    test "insertchar/3 inserts one grapheme and clamps the index" do
      assert Rathena.insertchar("laughter", "snake", 0) == "slaughter"
      assert Rathena.insertchar("a🙂c", "é", 2) == "a🙂éc"
      assert Rathena.insertchar("abc", "!", -5) == "!abc"
      assert Rathena.insertchar("abc", "!", 99) == "abc!"
    end

    test "strpos/3 returns Unicode grapheme positions from an optional offset" do
      assert Rathena.strpos("aé🙂barbar", "bar") == 3
      assert Rathena.strpos("aé🙂barbar", "bar", 4) == 6
      assert Rathena.strpos("foobar", "baz") == -1
      assert Rathena.strpos("foobar", "") == -1
    end

    test "countstr/3 counts non-overlapping matches with optional case folding" do
      assert Rathena.countstr("test test Test", "test") == 2
      assert Rathena.countstr("test test Test", "test", 0) == 3
      assert Rathena.countstr("aaaa", "aa") == 2
      assert Rathena.countstr("abc", "") == 0
    end

    test "replacestr supports case folding and a replacement limit" do
      assert Rathena.replacestr("testing tester", "test", "dash") == "dashing dasher"
      assert Rathena.replacestr("Donkey", "don", "mon", 0) == "monkey"

      assert Rathena.replacestr("test test test test", "test", "yay", 0, 3) ==
               "yay yay yay test"

      assert Rathena.replacestr("abc", "", "x") == "abc"
    end

    test "delchar/2 removes one grapheme at the index, out-of-range unchanged" do
      assert Rathena.delchar("hello", 1) == "hllo"
      assert Rathena.delchar("aé🙂z", 2) == "aéz"
      assert Rathena.delchar("abc", 0) == "bc"
      assert Rathena.delchar("abc", -1) == "abc"
      assert Rathena.delchar("abc", 3) == "abc"
      assert Rathena.delchar("abc", 99) == "abc"
    end
  end

  describe "regex, math, item, and formatting helpers" do
    test "preg_match/3 returns capture count, supports offsets, and safely rejects bad patterns" do
      assert Rathena.preg_match("^[aeiou]", "apple") == 1
      assert Rathena.preg_match("(a)(p)", "apple") == 3
      assert Rathena.preg_match("apple", "xapple", 1) == 1
      assert Rathena.preg_match("^apple", "xapple", 1) == 0
      assert Rathena.preg_match("[", "apple") == 0
      assert Rathena.preg_match("z", "apple") == 0
    end

    test "pow/2 raises integer values and truncates fractional results" do
      assert Rathena.pow(2, 3) == 8
      assert Rathena.pow(-1, 5) == -1
      assert Rathena.pow(2, -2) == 0
    end

    test "getitemname/1 resolves ids and Aegis names and returns null when unknown" do
      assert Rathena.getitemname(501) == "Red Potion"
      assert Rathena.getitemname("Red_Potion") == "Red Potion"
      assert Rathena.getitemname(-1) == "null"
      assert Rathena.getitemname("Missing_Item") == "null"
    end

    test "format/2 interpolates sequential string/integer placeholders and escaped percents" do
      assert Rathena.format("The %s contains %d monkeys (100%%)", ["zoo", 5]) ==
               "The zoo contains 5 monkeys (100%)"

      assert Rathena.format("%d %s", ["12", "apples"]) == "12 apples"
      assert Rathena.format("missing %s", []) == ""
    end
  end
end
