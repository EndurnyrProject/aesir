defmodule Aesir.ZoneServer.Mmo.Skills.NvFirstaidTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.NvFirstaid

  defp caster(hp, max_hp) do
    %{
      character_id: 4000,
      stats: %{
        current_state: %{hp: hp, sp: 50},
        derived_stats: %{max_hp: max_hp}
      }
    }
  end

  test "Catalog.active_module_for/1 resolves nv_firstaid" do
    assert {:ok, NvFirstaid} = Catalog.active_module_for(:nv_firstaid)
  end

  test "definition charges 3 SP at level 1" do
    {:ok, definition} = Catalog.by_id(142)
    assert definition.sp_cost == [3]
    assert definition.target_type == :self
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
