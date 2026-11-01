defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncreaseAgiTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncreaseAgi
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(overrides), do: struct(%StatusEntry{type: :sc_increaseagi, state: %{}}, overrides)

  describe "modifiers/2 flat movement haste" do
    test "applies a flat -25 haste regardless of skill level" do
      assert %{haste_rate: 25} = IncreaseAgi.modifiers(entry(val1: 1, val2: 6), %{})
      assert %{haste_rate: 25} = IncreaseAgi.modifiers(entry(val1: 10, val2: 15), %{})
    end

    test "scales AGI from val2 and grants the direct ASPD bonus only in renewal" do
      for {level, agi} <- [{1, 6}, {10, 15}] do
        modifiers = IncreaseAgi.modifiers(entry(val1: level, val2: agi), %{})
        assert modifiers.agi == agi
        assert modifiers.aspd == if(GameMode.mode() == :renewal, do: level, else: 0)
      end
    end
  end
end
