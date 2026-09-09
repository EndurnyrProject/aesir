defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsUnfairlytrickTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsUnfairlytrick

  @tag game_mode: :renewal
  test "renewal cuts zeny skill costs by 20 percent" do
    assert BsUnfairlytrick.zeny_cost_reduction(1, %{}) == 20
  end

  @tag game_mode: :pre_renewal
  test "classic cuts zeny skill costs by 10 percent" do
    assert BsUnfairlytrick.zeny_cost_reduction(1, %{}) == 10
  end
end
