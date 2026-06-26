defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.BlessingTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Blessing
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(val1, val2),
    do: %StatusEntry{type: :sc_blessing, val1: val1, val2: val2, state: %{}}

  describe "modifiers/2 - normal blessing (val2 > 0)" do
    test "grants HIT equal to val1 * 2" do
      instance = entry(10, 10)

      assert %{hit: 20} = Blessing.modifiers(instance, %{target: %{}})
    end

    test "grants STR, INT, DEX each equal to val2" do
      instance = entry(10, 7)

      assert %{str: 7, int: 7, dex: 7, hit: 20} = Blessing.modifiers(instance, %{target: %{}})
    end

    test "HIT scales with val1, not val2" do
      instance = entry(5, 10)

      assert %{hit: 10} = Blessing.modifiers(instance, %{target: %{}})
    end
  end

  describe "modifiers/2 - undead/demon (val2 = 0)" do
    test "halves STR, INT, DEX and HIT" do
      instance = entry(10, 0)
      context = %{target: %{str: 60, int: 40, dex: 50, hit: 80}}

      mods = Blessing.modifiers(instance, context)

      assert mods.str == -30
      assert mods.int == -20
      assert mods.dex == -25
      assert mods.hit == -40
    end
  end
end
