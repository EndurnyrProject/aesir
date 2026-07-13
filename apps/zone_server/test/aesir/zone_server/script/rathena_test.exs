defmodule Aesir.ZoneServer.Script.RathenaTest do
  @moduledoc """
  Covers the `input` range helpers backing rAthena's `input <var>,<min>,<max>`
  return value (0 in range, 1 below/too short, 2 above/too long).
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Script.Rathena

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
end
