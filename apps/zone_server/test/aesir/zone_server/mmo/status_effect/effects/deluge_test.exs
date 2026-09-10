defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DelugeTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Deluge
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context

  defp instance(level), do: %StatusEntry{type: :sc_deluge, val1: level, state: %{}}

  # rAthena src/map/status.cpp:11019-11033 (deluge_eff, enchant_eff) and
  # 3204-3205 (max HP bonus percent).
  @tag game_mode: :renewal
  test "raises max HP by the exact tabulated percent at levels 1 through 5" do
    for {level, percent} <- [{1, 5}, {2, 9}, {3, 12}, {4, 14}, {5, 15}] do
      assert Map.get(Deluge.modifiers(instance(level), %{unit_type: :player}), :max_hp_rate) ==
               percent
    end
  end

  test "raises the water element ratio by the exact tabulated points at levels 1 through 5" do
    for {level, points} <- [{1, 10}, {2, 14}, {3, 17}, {4, 19}, {5, 20}] do
      for unit_type <- [:player, :mob] do
        modifiers = Deluge.modifiers(instance(level), %{unit_type: unit_type})

        assert Map.get(modifiers, {:element_ratio, :water}) == points
      end
    end
  end

  @tag game_mode: :renewal
  test "applies unconditionally to every unit type, with no defense-element gate" do
    for unit_type <- [:player, :mob] do
      modifiers = Deluge.modifiers(instance(5), %{unit_type: unit_type})

      assert Map.get(modifiers, :max_hp_rate) == 15
      assert Map.get(modifiers, {:element_ratio, :water}) == 20
    end
  end

  test "is a buff that is dispellable and unsaved, per rAthena db/re/status.yml" do
    metadata = Deluge.metadata()

    assert Deluge.id() == :sc_deluge
    assert metadata.no_dispel == false
    assert metadata.no_save == true
  end

  @tag game_mode: :pre_renewal
  test "classic grants the stat bonus only to holders of the water defence element" do
    stub(UnitRegistry, :get_unit_info, fn
      :mob, 1 -> {:ok, %{element: :water}}
      :mob, 2 -> {:ok, %{element: :neutral}}
    end)

    matching = Deluge.modifiers(instance(5), %{unit_type: :mob, target_id: 1})
    other = Deluge.modifiers(instance(5), %{unit_type: :mob, target_id: 2})

    assert Map.get(matching, :max_hp_rate) == 15
    assert Map.get(matching, {:element_ratio, :water}) == 20
    refute Map.has_key?(other, :max_hp_rate)
    assert Map.get(other, {:element_ratio, :water}) == 20
  end
end
