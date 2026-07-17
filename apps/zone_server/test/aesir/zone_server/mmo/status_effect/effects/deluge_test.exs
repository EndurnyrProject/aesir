defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DelugeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Deluge
  alias Aesir.ZoneServer.Mmo.StatusEntry

  defp instance(level), do: %StatusEntry{type: :sc_deluge, val1: level, state: %{}}

  # rAthena src/map/status.cpp:11019-11033 (deluge_eff, enchant_eff) and
  # 3204-3205 (max HP bonus percent).
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
end
