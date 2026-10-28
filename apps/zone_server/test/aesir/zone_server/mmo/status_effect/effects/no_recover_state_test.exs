defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.NoRecoverStateTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.NoRecoverState
  alias Aesir.ZoneServer.Mmo.StatusEntry

  test "stops all regeneration" do
    assert NoRecoverState.modifiers(%StatusEntry{}, %{}) == %{no_regen: true}
  end
end
