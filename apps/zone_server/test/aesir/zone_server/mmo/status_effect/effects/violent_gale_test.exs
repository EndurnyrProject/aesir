defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ViolentGaleTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ViolentGale
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context

  defp instance(level), do: %StatusEntry{type: :sc_violentgale, val1: level, state: %{}}

  # rAthena src/map/status.cpp:11008-11018 (val2 = val1 * 3, enchant_eff) and
  # 7637-7638 (flee bonus).
  @tag game_mode: :renewal
  test "raises flee by the exact tabulated amount at levels 1 through 5" do
    for {level, flee} <- [{1, 3}, {2, 6}, {3, 9}, {4, 12}, {5, 15}] do
      assert Map.get(ViolentGale.modifiers(instance(level), %{unit_type: :player}), :flee) == flee
    end
  end

  test "raises the wind element ratio by the exact tabulated points at levels 1 through 5" do
    for {level, points} <- [{1, 10}, {2, 14}, {3, 17}, {4, 19}, {5, 20}] do
      for unit_type <- [:player, :mob] do
        modifiers = ViolentGale.modifiers(instance(level), %{unit_type: unit_type})

        assert Map.get(modifiers, {:element_ratio, :wind}) == points
      end
    end
  end

  @tag game_mode: :renewal
  test "applies unconditionally to every unit type, with no defense-element gate" do
    for unit_type <- [:player, :mob] do
      modifiers = ViolentGale.modifiers(instance(5), %{unit_type: unit_type})

      assert Map.get(modifiers, :flee) == 15
      assert Map.get(modifiers, {:element_ratio, :wind}) == 20
    end
  end

  test "is a buff that is dispellable and unsaved, per rAthena db/re/status.yml" do
    metadata = ViolentGale.metadata()

    assert ViolentGale.id() == :sc_violentgale
    assert metadata.no_dispel == false
    assert metadata.no_save == true
  end

  @tag game_mode: :pre_renewal
  test "classic grants the stat bonus only to holders of the wind defence element" do
    stub(UnitRegistry, :get_unit_info, fn
      :mob, 1 -> {:ok, %{element: :wind}}
      :mob, 2 -> {:ok, %{element: :neutral}}
    end)

    matching = ViolentGale.modifiers(instance(5), %{unit_type: :mob, target_id: 1})
    other = ViolentGale.modifiers(instance(5), %{unit_type: :mob, target_id: 2})

    assert Map.get(matching, :flee) == 15
    assert Map.get(matching, {:element_ratio, :wind}) == 20
    refute Map.has_key?(other, :flee)
    assert Map.get(other, {:element_ratio, :wind}) == 20
  end
end
