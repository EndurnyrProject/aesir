defmodule Aesir.ZoneServer.Unit.BroadcastTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.Broadcast

  describe "delivery privacy" do
    for packet <- [%Aesir.Net.HomunculusResult{}, %Aesir.Net.HomunculusPrivateState{}],
        {path, call} <- [
          to_players: quote(do: Broadcast.to_players([], unquote(Macro.escape(packet)))),
          to_in_range:
            quote(
              do: Broadcast.to_in_range("privacy_test", 1, 1, 14, unquote(Macro.escape(packet)))
            ),
          to_visible_players:
            quote(
              do:
                Broadcast.to_visible_players(
                  %{visible_players: MapSet.new()},
                  unquote(Macro.escape(packet))
                )
            )
        ] do
      test "#{path} rejects #{inspect(packet.__struct__)}" do
        assert_raise ArgumentError, "owner-only messages cannot use generic broadcasts", fn ->
          unquote(call)
        end
      end
    end
  end

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
