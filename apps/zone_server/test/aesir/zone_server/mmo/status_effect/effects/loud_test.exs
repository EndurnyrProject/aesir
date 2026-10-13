defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.LoudTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Loud
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(overrides), do: struct(%StatusEntry{type: :sc_loud, state: %{}}, overrides)

  describe "modifiers/2" do
    @tag game_mode: :renewal
    test "renewal grants +4 STR and +30 status ATK" do
      assert %{str: 4, batk: 30} = Loud.modifiers(entry([]), %{})
    end

    @tag game_mode: :pre_renewal
    test "classic grants +4 STR only" do
      assert %{str: 4} == Loud.modifiers(entry([]), %{})
    end
  end

  describe "calc_flags" do
    test "includes :str and :atk" do
      assert :str in Loud.metadata().calc_flags
      assert :atk in Loud.metadata().calc_flags
    end
  end
end
