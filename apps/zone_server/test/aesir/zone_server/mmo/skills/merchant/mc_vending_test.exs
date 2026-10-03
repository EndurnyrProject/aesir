defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McVendingTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Merchant.McVending

  describe "max_slots/1" do
    test "is 2 + level, capped at 12" do
      assert McVending.max_slots(1) == 3
      assert McVending.max_slots(5) == 7
      assert McVending.max_slots(10) == 12
      assert McVending.max_slots(11) == 12
    end
  end
end
