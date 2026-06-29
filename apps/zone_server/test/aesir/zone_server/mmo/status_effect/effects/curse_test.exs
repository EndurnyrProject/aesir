defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CurseTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Curse
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(overrides), do: struct(%StatusEntry{type: :sc_curse, state: %{}}, overrides)

  describe "modifiers/2 movement_speed (rAthena status_calc_speed: max(val, 300))" do
    test "applies a flat +300 speed-rate slowdown" do
      assert %{movement_speed: 300} = Curse.modifiers(entry([]), %{})
    end

    test "keeps the LUK wipe and -25% ATK alongside the slowdown" do
      assert %{luk: 0, atk_rate: -25, movement_speed: 300} = Curse.modifiers(entry([]), %{})
    end
  end
end
