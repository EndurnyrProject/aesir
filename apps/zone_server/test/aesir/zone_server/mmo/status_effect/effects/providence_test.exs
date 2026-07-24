defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ProvidenceTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Providence
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp entry(overrides), do: struct(%StatusEntry{type: :sc_providence, state: %{}}, overrides)

  describe "modifiers/2" do
    test "grants 5% holy-element and demon-race resistance per skill level" do
      assert %{subele_holy: 5, subrace_demon: 5} = Providence.modifiers(entry(val1: 1), %{})
      assert %{subele_holy: 25, subrace_demon: 25} = Providence.modifiers(entry(val1: 5), %{})
    end
  end
end
