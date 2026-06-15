defmodule Aesir.ZoneServer.Unit.BroadcastTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.Broadcast

  describe "mob despawn pub/sub" do
    test "publish reaches a subscriber despite the .gat suffix mismatch" do
      # Players subscribe with the bare map name; mobs publish with the ".gat"
      # suffix. Both must resolve to the same topic.
      Broadcast.subscribe_mob_despawns("broadcast_test_map")
      Broadcast.publish_mob_despawn("broadcast_test_map.gat", 4242)

      assert_receive {:mob_despawned, 4242}
    end

    test "subscribers only get despawns for their own map" do
      Broadcast.subscribe_mob_despawns("broadcast_test_map_a")
      Broadcast.publish_mob_despawn("broadcast_test_map_b.gat", 99)

      refute_receive {:mob_despawned, 99}
    end
  end
end
