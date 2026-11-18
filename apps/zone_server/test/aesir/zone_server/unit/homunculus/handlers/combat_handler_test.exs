defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.CombatHandlerTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime

  test "basic attacks become eligible exactly at the attack delay" do
    homunculus = build(:homunculus_state, attack_delay_ms: 623)
    runtime = %Runtime{private_dirty: false, last_basic_attack_at_ms: 1_000}

    refute CombatHandler.basic_attack_ready?(runtime, homunculus, 1_622)
    assert CombatHandler.basic_attack_ready?(runtime, homunculus, 1_623)
  end
end
