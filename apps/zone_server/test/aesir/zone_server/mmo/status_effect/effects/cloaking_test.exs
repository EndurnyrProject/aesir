defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CloakingTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Cloaking
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(overrides), do: struct(%StatusEntry{type: :sc_cloaking, state: %{}}, overrides)

  describe "modifiers/2 movement_speed (rAthena not-against-wall slow: val1 < 3 ? 300 : 30 - 3*val1)" do
    test "levels below 3 apply the full +300 slowdown" do
      assert %{movement_speed: 300} = Cloaking.modifiers(entry(val1: 1), %{target: %{}})
      assert %{movement_speed: 300} = Cloaking.modifiers(entry(val1: 2), %{target: %{}})
    end

    test "level 3 applies a +21 slowdown" do
      assert %{movement_speed: 21} = Cloaking.modifiers(entry(val1: 3), %{target: %{}})
    end

    test "max level (10) removes the slowdown entirely" do
      assert %{movement_speed: 0} = Cloaking.modifiers(entry(val1: 10), %{target: %{}})
    end

    test "doubles CRIT from the target's current value" do
      assert %{cri: 42} = Cloaking.modifiers(entry(val1: 1), %{target: %{cri: 42}})
    end
  end
end
