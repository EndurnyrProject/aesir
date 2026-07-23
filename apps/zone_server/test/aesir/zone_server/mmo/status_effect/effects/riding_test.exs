defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.RidingTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Riding
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(overrides), do: struct(%StatusEntry{type: :sc_riding, state: %{}}, overrides)

  describe "metadata" do
    test "is a permanent, no_save, opt-bearing status carrying the riding option" do
      meta = Riding.metadata()

      assert meta.permanent == true
      assert meta.no_save == true
      assert meta.option == :riding
      assert meta.calc_flags == [:speed, :aspd]
    end
  end

  describe "modifiers/2 (movement +25%, ASPD penalty 50 - 10 * Cavalier Mastery level)" do
    test "level 0 (unlearned) keeps the full 50% ASPD slowdown alongside the speed bonus" do
      assert %{movement_speed: -25, aspd: -50} = Riding.modifiers(entry(val1: 0), %{})
    end

    test "mid level shrinks the ASPD slowdown proportionally" do
      assert %{movement_speed: -25, aspd: -20} = Riding.modifiers(entry(val1: 3), %{})
    end

    test "max level (5) removes the ASPD penalty entirely, speed bonus unchanged" do
      assert %{movement_speed: -25, aspd: 0} = Riding.modifiers(entry(val1: 5), %{})
    end
  end
end
