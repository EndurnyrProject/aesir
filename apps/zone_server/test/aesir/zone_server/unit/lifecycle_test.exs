defmodule Aesir.ZoneServer.Unit.LifecycleTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Lifecycle.Event

  test "subscribers receive one normalized death event" do
    assert :ok = Lifecycle.subscribe()

    assert :ok = Lifecycle.publish_death(:player, 1_001, "prontera")

    assert_receive {:unit_lifecycle,
                    %Event{
                      unit_type: :player,
                      unit_id: 1_001,
                      reason: :death,
                      old_map: "prontera",
                      new_map: nil
                    } = event}

    refute_receive {:unit_lifecycle, ^event}
  end
end
