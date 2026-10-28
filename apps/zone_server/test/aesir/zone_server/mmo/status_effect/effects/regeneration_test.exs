defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.RegenerationTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Regeneration
  alias Aesir.ZoneServer.Mmo.StatusEntry

  test "raises the HP and SP tick rates by level" do
    assert Regeneration.modifiers(%StatusEntry{val1: 1}, %{}) ==
             %{hp_regen_tick_rate: 200, sp_regen_tick_rate: 100}

    assert Regeneration.modifiers(%StatusEntry{val1: 3}, %{}) ==
             %{hp_regen_tick_rate: 300, sp_regen_tick_rate: 300}
  end

  test "a val4 stops the flagged natural regeneration instead" do
    assert Regeneration.modifiers(%StatusEntry{val1: 10, val4: 3}, %{}) ==
             %{no_natural_hp_regen: true, no_natural_sp_regen: true}

    assert Regeneration.modifiers(%StatusEntry{val1: 10, val4: 1}, %{}) ==
             %{no_natural_hp_regen: true}

    assert Regeneration.modifiers(%StatusEntry{val1: 10, val4: 2}, %{}) ==
             %{no_natural_sp_regen: true}
  end
end
