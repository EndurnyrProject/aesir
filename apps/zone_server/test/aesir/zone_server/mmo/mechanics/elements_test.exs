defmodule Aesir.ZoneServer.Mmo.Mechanics.ElementsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Mechanics.Elements.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.Elements.Renewal

  @elements [
    :neutral,
    :water,
    :earth,
    :fire,
    :wind,
    :poison,
    :holy,
    :shadow,
    :ghost,
    :undead
  ]

  @differing_rows [
    {:neutral, :ghost, 1, 0.7, 0.25, "Level 1 -> Neutral -> Ghost"},
    {:water, :fire, 1, 2.0, 1.5, "Level 1 -> Water -> Fire"},
    {:poison, :undead, 1, 0.5, -0.25, "Level 1 -> Poison -> Undead"},
    {:water, :water, 2, 0.2, 0.0, "Level 2 -> Water -> Water"},
    {:holy, :holy, 4, 0.0, -1.0, "Level 4 -> Holy -> Holy"}
  ]

  test "mode tables retain canonical differing rows" do
    for {attack, defense, level, renewal, pre_renewal, row} <- @differing_rows do
      provenance = "db/pre-re/attr_fix.yml: #{row}"

      assert_in_delta Renewal.get_modifier(attack, defense, level, 0),
                      renewal,
                      1.0e-12,
                      provenance

      assert_in_delta PreRenewal.get_modifier(attack, defense, level, 0),
                      pre_renewal,
                      1.0e-12,
                      provenance
    end
  end

  test "both implementations support every element pair at defense levels 1 through 4" do
    modifiers =
      for implementation <- [Renewal, PreRenewal],
          attack <- @elements,
          defense <- @elements,
          level <- 1..4 do
        implementation.get_modifier(attack, defense, level, 0)
      end

    assert length(modifiers) == 800
    assert Enum.all?(modifiers, &is_float/1)
  end

  test "renewal preserves level scaling and fallback behavior" do
    assert Enum.map(1..4, &Renewal.get_modifier(:water, :fire, &1, 0)) == [2.0, 2.2, 2.4, 2.6]

    for {actual, expected} <-
          Enum.zip(
            Enum.map(1..4, &Renewal.get_modifier(:fire, :water, &1, 0)),
            [0.9, 0.72, 0.54, 0.36]
          ) do
      assert_in_delta actual, expected, 1.0e-12
    end

    assert Renewal.get_modifier(:invalid, :neutral, 1, 0) == 1.0
    assert Renewal.get_modifier(:water, :fire, 99, 0) == 2.0
  end

  test "ratio bonuses remain additive percentage points in both modes" do
    assert_in_delta Renewal.get_modifier(:fire, :earth, 4, 20), 2.8, 1.0e-12
    assert_in_delta PreRenewal.get_modifier(:fire, :earth, 4, 20), 2.2, 1.0e-12
    assert_in_delta PreRenewal.get_modifier(:fire, :earth, 4, 1), 2.01, 1.0e-12
  end
end
