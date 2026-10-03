defmodule Aesir.ZoneServer.Mmo.Skills.Monk.FuryTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skills.Monk.Fury
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup :setup_ets_tables

  test "Fury is active while an unexpired or permanent entry exists" do
    refute Fury.active?(1)

    :ok = StatusStorage.apply_status(:player, 1, :sc_explosionspirits, duration: 180_000)
    assert Fury.active?(1)

    StatusStorage.update_status(:player, 1, :sc_explosionspirits, &%{&1 | expires_at: nil})
    assert Fury.active?(1)

    past = System.monotonic_time(:millisecond) - 1

    StatusStorage.update_status(
      :player,
      1,
      :sc_explosionspirits,
      &%{&1 | expires_at: past}
    )

    refute Fury.active?(1)
  end
end
