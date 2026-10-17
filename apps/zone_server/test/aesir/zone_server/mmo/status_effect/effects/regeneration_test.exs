defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.RegenerationTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Regeneration
  alias Aesir.ZoneServer.Mmo.StatusEntry

  test "raises HP and SP regeneration by level" do
    assert Regeneration.modifiers(%StatusEntry{val1: 1}, %{}) == %{hp_regen: 200, sp_regen: 100}
    assert Regeneration.modifiers(%StatusEntry{val1: 3}, %{}) == %{hp_regen: 300, sp_regen: 300}
  end

  test "a val4 blocks the flagged natural regeneration instead" do
    assert Regeneration.modifiers(%StatusEntry{val1: 10, val4: 3}, %{}) ==
             %{hp_regen: -100, sp_regen: -100}

    assert Regeneration.modifiers(%StatusEntry{val1: 10, val4: 1}, %{}) == %{hp_regen: -100}
    assert Regeneration.modifiers(%StatusEntry{val1: 10, val4: 2}, %{}) == %{sp_regen: -100}
  end
end
