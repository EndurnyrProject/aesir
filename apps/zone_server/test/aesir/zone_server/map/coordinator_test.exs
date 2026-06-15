defmodule Aesir.ZoneServer.Map.CoordinatorTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Map.Coordinator

  describe "mob_died/2 routing" do
    test "routes a .gat-suffixed map name to the clean-named coordinator" do
      # Coordinators register under the clean map name (no .gat), but mobs carry
      # their map_name with the .gat suffix. Regression test for respawns never
      # firing because the cast was routed to an unregistered .gat name.
      {:ok, _} = Registry.register(Aesir.ZoneServer.MapRegistry, "coordinator_test_map", nil)

      Coordinator.mob_died("coordinator_test_map.gat", 4242)

      assert_receive {:"$gen_cast", {:mob_died, 4242}}
    end
  end
end
