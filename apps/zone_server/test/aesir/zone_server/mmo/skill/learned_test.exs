defmodule Aesir.ZoneServer.Mmo.Skill.LearnedTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Learned

  test "from_character/1 returns an empty map when empty or nil" do
    assert Learned.from_character(nil) == %{}
    assert Learned.from_character(%{}) == %{}
  end

  test "from_character/1 converts string keys to integers" do
    assert Learned.from_character(%{"29" => 3, "5" => 1}) == %{29 => 3, 5 => 1}
  end

  test "dump/1 converts integer keys back to strings" do
    assert Learned.dump(%{29 => 3}) == %{"29" => 3}
  end

  test "learned_level/2 returns level or 0" do
    assert Learned.learned_level(%{29 => 3}, 29) == 3
    assert Learned.learned_level(%{29 => 3}, 5) == 0
  end
end
