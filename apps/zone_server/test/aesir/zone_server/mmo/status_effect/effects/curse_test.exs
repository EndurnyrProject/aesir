defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CurseTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Curse

  defp entry(overrides), do: build(:status_entry, Keyword.put(overrides, :type, :sc_curse))

  describe "modifiers/2 movement_speed (rAthena status_calc_speed: max(val, 300))" do
    test "applies a flat +300 speed-rate slowdown" do
      assert %{movement_speed: 300} = Curse.modifiers(entry([]), %{})
    end

    test "keeps the LUK wipe and -25% ATK alongside the slowdown" do
      assert %{luk: 0, atk_rate: -25, movement_speed: 300} = Curse.modifiers(entry([]), %{})
    end
  end
end
