defmodule Aesir.ZoneServer.Map.LifecycleTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Map.Lifecycle

  test "subscribers on this node receive one initialized event" do
    assert :ok = Lifecycle.subscribe()

    assert :ok = Lifecycle.publish_initialized()

    assert_receive {:map_lifecycle, :initialized}
  end
end
