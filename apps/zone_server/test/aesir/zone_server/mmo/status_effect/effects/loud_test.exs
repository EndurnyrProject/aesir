defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.LoudTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Loud
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(overrides), do: struct(%StatusEntry{type: :sc_loud, state: %{}}, overrides)

  describe "modifiers/2" do
    test "grants +4 STR and +30 base ATK" do
      assert %{str: 4, watk: 30} = Loud.modifiers(entry([]), %{})
    end
  end

  describe "calc_flags" do
    test "includes :str and :watk" do
      assert :str in Loud.metadata().calc_flags
      assert :watk in Loud.metadata().calc_flags
    end
  end
end
