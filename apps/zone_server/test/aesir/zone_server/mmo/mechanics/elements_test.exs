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
    {:neutral, :ghost, 1, 0.9, 0.25, "Level 1 -> Neutral -> Ghost"},
    {:water, :wind, 1, 0.9, 0.5, "Level 1 -> Water -> Wind"},
    {:poison, :undead, 1, 0.75, -0.25, "Level 1 -> Poison -> Undead"},
    {:water, :water, 2, 0.0, 0.0, "Level 2 -> Water -> Water"},
    {:holy, :holy, 4, 0.0, -1.0, "Level 4 -> Holy -> Holy"}
  ]

  test "mode tables retain canonical differing rows" do
    for {attack, defense, level, renewal, pre_renewal, row} <- @differing_rows do
      provenance = row

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
    assert Enum.map(1..4, &Renewal.get_modifier(:water, :fire, &1, 0)) == [1.5, 1.75, 2.0, 2.0]
    assert Enum.map(1..4, &Renewal.get_modifier(:fire, :water, &1, 0)) == [0.9, 0.8, 0.7, 0.6]

    assert Renewal.get_modifier(:invalid, :neutral, 1, 0) == 1.0
    assert Renewal.get_modifier(:water, :fire, 99, 0) == 1.0
  end

  test "field bonuses add Renewal ratio points and multiply classic damage" do
    assert_in_delta Renewal.get_modifier(:fire, :earth, 4, 20), 2.2, 1.0e-12
    assert_in_delta PreRenewal.get_modifier(:fire, :earth, 4, 20), 2.4, 1.0e-12
    assert_in_delta PreRenewal.get_modifier(:fire, :earth, 4, 1), 2.02, 1.0e-12
  end

  describe "ratio/3" do
    test "renewal level-1 rows come from the renewal attribute table" do
      assert Renewal.ratio(:neutral, :ghost, 1) == 90
      assert Renewal.ratio(:water, :fire, 1) == 150
      assert Renewal.ratio(:fire, :earth, 1) == 150
    end

    test "every defense level is its own table, not a scaled level 1" do
      assert Enum.map(1..4, &Renewal.ratio(:water, :fire, &1)) == [150, 175, 200, 200]
      assert Enum.map(1..4, &Renewal.ratio(:poison, :undead, &1)) == [75, 50, 25, 0]
      assert Enum.map(1..4, &PreRenewal.ratio(:poison, :undead, &1)) == [-25, -50, -75, -100]
    end

    test "every element pair and level resolves to an integer percentage in both modes" do
      for implementation <- [Renewal, PreRenewal],
          attack <- @elements,
          defense <- @elements,
          level <- 1..4 do
        ratio = implementation.ratio(attack, defense, level)
        assert is_integer(ratio) and ratio in -100..200
      end
    end
  end

  describe "adjust_damage/2" do
    defp adjustment(attack, defense, level, modifiers \\ [], allow_negative? \\ false) do
      %{
        attack_element: attack,
        defense_element: defense,
        defense_level: level,
        modifiers: modifiers,
        allow_negative_ratio?: allow_negative?
      }
    end

    test "renewal rounds the reduction down while classic truncates the product" do
      assert Renewal.adjust_damage(101, adjustment(:water, :water, 1)) == 26
      assert PreRenewal.adjust_damage(101, adjustment(:water, :water, 1)) == 25
    end

    test "classic applies a field bonus to the running damage before the table" do
      assert PreRenewal.adjust_damage(3, adjustment(:fire, :earth, 3, volcano: 20)) == 6
    end

    test "renewal adds field and web bonuses to the ratio" do
      assert Renewal.adjust_damage(3, adjustment(:fire, :earth, 3, volcano: 20)) == 6
      assert Renewal.adjust_damage(101, adjustment(:fire, :earth, 1, spider_web: 100)) == 252
    end

    test "a zero ratio stays zero" do
      assert Renewal.adjust_damage(101, adjustment(:poison, :poison, 1)) == 0
      assert PreRenewal.adjust_damage(101, adjustment(:poison, :poison, 1)) == 0
    end

    test "a negative ratio clamps to zero unless the call allows recovery" do
      assert PreRenewal.adjust_damage(101, adjustment(:poison, :undead, 1)) == 0
      assert PreRenewal.adjust_damage(101, adjustment(:poison, :undead, 1, [], true)) == -25
    end
  end
end
