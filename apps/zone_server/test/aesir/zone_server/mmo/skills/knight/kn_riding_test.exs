defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnRidingTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnRiding

  test "a mounted rider carries 10000 more weight" do
    assert KnRiding.max_weight_bonus(1, %{riding: true}) == 10_000
    assert KnRiding.max_weight_bonus(1, %{riding: false}) == 0
  end
end
