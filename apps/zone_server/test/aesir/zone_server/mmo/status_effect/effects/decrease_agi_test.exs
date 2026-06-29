defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DecreaseAgiTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DecreaseAgi
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(overrides), do: struct(%StatusEntry{type: :sc_decreaseagi, state: %{}}, overrides)

  describe "modifiers/2 movement_speed (rAthena status_calc_speed: max(val, 25))" do
    test "applies a flat +25 slowdown regardless of skill level" do
      assert %{movement_speed: 25} = DecreaseAgi.modifiers(entry(val1: 1), %{})
      assert %{movement_speed: 25} = DecreaseAgi.modifiers(entry(val1: 5), %{})
      assert %{movement_speed: 25} = DecreaseAgi.modifiers(entry(val1: 10), %{})
    end

    test "still scales the AGI penalty with skill level" do
      assert %{agi: -3} = DecreaseAgi.modifiers(entry(val1: 1), %{})
      assert %{agi: -12} = DecreaseAgi.modifiers(entry(val1: 10), %{})
    end
  end
end
