defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncreaseAgiTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncreaseAgi
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(overrides), do: struct(%StatusEntry{type: :sc_increaseagi, state: %{}}, overrides)

  describe "modifiers/2 movement_speed (rAthena status_calc_speed: max(val, 25) haste)" do
    test "applies a flat -25 haste regardless of skill level" do
      assert %{movement_speed: -25} = IncreaseAgi.modifiers(entry(val1: 1, val2: 6), %{})
      assert %{movement_speed: -25} = IncreaseAgi.modifiers(entry(val1: 10, val2: 15), %{})
    end

    test "still scales AGI (val2) and ASPD (val1)" do
      assert %{agi: 6, aspd: 1} = IncreaseAgi.modifiers(entry(val1: 1, val2: 6), %{})
      assert %{agi: 15, aspd: 10} = IncreaseAgi.modifiers(entry(val1: 10, val2: 15), %{})
    end
  end
end
