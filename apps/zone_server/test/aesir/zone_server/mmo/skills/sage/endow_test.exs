defmodule Aesir.ZoneServer.Mmo.Skills.Sage.EndowTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Sage.Endow

  @tag game_mode: :renewal
  test "renewal endows never fail" do
    refute Endow.classic_failure?(1, fn 100 -> 100 end)
  end

  @tag game_mode: :pre_renewal
  test "classic endows succeed 60 plus 10 per level percent of the time" do
    refute Endow.classic_failure?(1, fn 100 -> 70 end)
    assert Endow.classic_failure?(1, fn 100 -> 71 end)
    refute Endow.classic_failure?(4, fn 100 -> 100 end)
  end
end
