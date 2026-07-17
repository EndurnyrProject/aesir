defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.VolcanoTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Volcano
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp instance(level), do: %StatusEntry{type: :sc_volcano, val1: level, state: %{}}

  # rAthena src/map/status.cpp:10994-11007 (val2 = 5 + val1 * 5, enchant_eff),
  # 7300-7301 (batk), 7352-7353 (watk, BL_MOB only), 7447-7448 (matk).
  test "grants players exact ATK and MATK at levels 1 through 5" do
    for {level, atk} <- [{1, 10}, {2, 15}, {3, 20}, {4, 25}, {5, 30}] do
      modifiers = Volcano.modifiers(instance(level), %{unit_type: :player})

      assert Map.get(modifiers, :atk) == atk
      assert Map.get(modifiers, :matk) == atk
      refute Map.has_key?(modifiers, :watk)
    end
  end

  test "grants mobs exact weapon ATK, and never player ATK/MATK, at levels 1 through 5" do
    for {level, watk} <- [{1, 10}, {2, 15}, {3, 20}, {4, 25}, {5, 30}] do
      modifiers = Volcano.modifiers(instance(level), %{unit_type: :mob})

      assert Map.get(modifiers, :watk) == watk
      refute Map.has_key?(modifiers, :atk)
      refute Map.has_key?(modifiers, :matk)
    end
  end

  test "raises the fire element ratio by the exact tabulated points at levels 1 through 5" do
    for {level, points} <- [{1, 10}, {2, 14}, {3, 17}, {4, 19}, {5, 20}] do
      for unit_type <- [:player, :mob] do
        modifiers = Volcano.modifiers(instance(level), %{unit_type: unit_type})

        assert Map.get(modifiers, {:element_ratio, :fire}) == points
      end
    end
  end

  test "is a buff that is dispellable and unsaved, per rAthena db/re/status.yml" do
    metadata = Volcano.metadata()

    assert Volcano.id() == :sc_volcano
    assert metadata.no_dispel == false
    assert metadata.no_save == true
  end
end
