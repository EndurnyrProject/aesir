defmodule Aesir.ZoneServer.Map.CoordinatorAnnounceTest do
  @moduledoc """
  Verifies the `Coordinator` relays a server-wide announce (e.g. a flagged
  refine outcome) it receives via `Aesir.Commons.InterServer.PubSub` down to
  the map's local players, without calling into any refine module directly.
  """

  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Map.Coordinator
  alias Phoenix.PubSub

  @map_name "coordinator_announce_test_map"

  test "relays a received server_announce event to the map's local players" do
    PubSub.subscribe(Aesir.PubSub, "map:#{@map_name}")

    state = %Coordinator{map_name: @map_name}
    event = %{event: "server_announce", message: %{nameid: 1201, refine: 10}}

    assert {:noreply, ^state} = Coordinator.handle_info({:server_announce, event}, state)

    assert_receive {:map_announcement, %{nameid: 1201, refine: 10}}, 1000
  end
end
