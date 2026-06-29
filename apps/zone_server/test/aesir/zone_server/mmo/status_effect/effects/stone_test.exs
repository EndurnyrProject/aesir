defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StoneTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Stone
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(overrides), do: struct(%StatusEntry{type: :sc_stone, state: %{}}, overrides)

  describe "speed handling (rAthena: SC_STONE is absent from status_calc_speed)" do
    test "does not declare a :speed calc flag" do
      refute :speed in Stone.metadata().calc_flags
    end

    test "wait phase carries no :movement_speed modifier" do
      refute Map.has_key?(Stone.modifiers(entry(phase: :wait), %{}), :movement_speed)
    end

    test "stone phase carries no :movement_speed modifier" do
      refute Map.has_key?(Stone.modifiers(entry(phase: :stone), %{}), :movement_speed)
    end
  end
end
