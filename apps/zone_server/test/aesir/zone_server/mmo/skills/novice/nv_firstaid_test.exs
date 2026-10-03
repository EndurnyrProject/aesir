defmodule Aesir.ZoneServer.Mmo.Skills.Novice.NvFirstaidTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Novice.NvFirstaid

  defp caster(hp, max_hp) do
    %{
      character_id: 4000,
      stats: %{
        current_state: %{hp: hp, sp: 50},
        derived_stats: %{max_hp: max_hp}
      }
    }
  end

  test "cast/4 heals a flat 5 HP" do
    {:ok, definition} = Catalog.by_id(142)

    assert {:ok, %{stats: %{current_state: %{hp: 45}}}} =
             NvFirstaid.cast(caster(40, 100), :self, 1, definition)
  end

  test "cast/4 clamps the heal at max HP" do
    {:ok, definition} = Catalog.by_id(142)

    assert {:ok, %{stats: %{current_state: %{hp: 100}}}} =
             NvFirstaid.cast(caster(98, 100), :self, 1, definition)
  end
end
