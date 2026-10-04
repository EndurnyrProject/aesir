defmodule Aesir.ZoneServer.Mmo.Skills.Clown.FormulasTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Clown.Formulas

  @tag game_mode: :renewal
  test "Arrow Vulcan scales the renewal ratio by base level" do
    assert Formulas.arrow_vulcan_ratio(10, 99) == 1485
    assert Formulas.arrow_vulcan_ratio(1, 50) == 300
  end

  @tag game_mode: :pre_renewal
  test "classic Arrow Vulcan ignores base level" do
    assert Formulas.arrow_vulcan_ratio(10, 99) == 1200
    assert Formulas.arrow_vulcan_ratio(1, 50) == 300
  end
end
