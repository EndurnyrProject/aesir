defmodule Aesir.ZoneServer.Mmo.Skill.AuditTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Audit
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  describe "expand_levels/3" do
    test "a scalar value applies to every level" do
      assert Audit.expand_levels(8, "Amount", 5) == [8, 8, 8, 8, 8]
    end

    test "an explicit full list is returned unchanged" do
      entries = [
        %{"Level" => 1, "Amount" => 8},
        %{"Level" => 2, "Amount" => 15},
        %{"Level" => 3, "Amount" => 20}
      ]

      assert Audit.expand_levels(entries, "Amount", 3) == [8, 15, 20]
    end

    test "a sparse list with a linear step-1 trend extrapolates the diff" do
      entries = [
        %{"Level" => 1, "Amount" => 10},
        %{"Level" => 2, "Amount" => 20},
        %{"Level" => 3, "Amount" => 30}
      ]

      assert Audit.expand_levels(entries, "Amount", 5) == [10, 20, 30, 40, 50]
    end

    test "a sparse list with a step-2 trend extrapolates every other level" do
      entries = [
        %{"Level" => 1, "Amount" => 10},
        %{"Level" => 2, "Amount" => 10},
        %{"Level" => 3, "Amount" => 20},
        %{"Level" => 4, "Amount" => 20}
      ]

      assert Audit.expand_levels(entries, "Amount", 6) == [10, 10, 20, 20, 30, 30]
    end

    test "a sparse list with no matching trend fills with the last listed value" do
      entries = [
        %{"Level" => 1, "Amount" => 10},
        %{"Level" => 2, "Amount" => 25},
        %{"Level" => 3, "Amount" => 27}
      ]

      assert Audit.expand_levels(entries, "Amount", 5) == [10, 25, 27, 27, 27]
    end

    test "a decreasing trend that would cross below 1 caps at 1 and stops decreasing" do
      entries = [
        %{"Level" => 1, "Amount" => 5},
        %{"Level" => 2, "Amount" => 3},
        %{"Level" => 3, "Amount" => 1}
      ]

      assert Audit.expand_levels(entries, "Amount", 5) == [5, 3, 1, 1, 1]
    end

    test "a single-entry list has no step to try and fills with the last (only) value" do
      entries = [%{"Level" => 1, "Amount" => 8}]

      assert Audit.expand_levels(entries, "Amount", 5) == [8, 8, 8, 8, 8]
    end
  end

  describe "compare/3" do
    @definition %Definition{
      id: 5,
      name: :sm_bash,
      display_name: "Bash",
      max_level: 10,
      range: 1,
      sp_cost: [8, 8, 8, 8, 8, 15, 15, 15, 15, 15]
    }

    @matching_row %{
      "MaxLevel" => 10,
      "Range" => -1,
      "HitCount" => 1,
      "Requires" => %{
        "SpCost" => [
          %{"Level" => 1, "Amount" => 8},
          %{"Level" => 2, "Amount" => 8},
          %{"Level" => 3, "Amount" => 8},
          %{"Level" => 4, "Amount" => 8},
          %{"Level" => 5, "Amount" => 8},
          %{"Level" => 6, "Amount" => 15},
          %{"Level" => 7, "Amount" => 15},
          %{"Level" => 8, "Amount" => 15},
          %{"Level" => 9, "Amount" => 15},
          %{"Level" => 10, "Amount" => 15}
        ]
      }
    }

    test "returns an empty list for a fixture row equal to the definition" do
      assert Audit.compare(@definition, @matching_row, :renewal) == []
    end

    test "returns one finding per differing field" do
      row = put_in(@matching_row["Range"], 9)

      assert [%{field: :range, aesir: 1, source: source}] =
               Audit.compare(@definition, row, :renewal)

      assert source == List.duplicate(9, 10)
    end

    test "skips fixed_cast_time when mode is pre_renewal" do
      definition = %{
        @definition
        | fixed_cast_time: [100, 100, 100, 100, 100, 100, 100, 100, 100, 100]
      }

      row = Map.put(@matching_row, "FixedCastTime", 300)

      refute Enum.any?(
               Audit.compare(definition, row, :pre_renewal),
               &(&1.field == :fixed_cast_time)
             )

      assert Enum.any?(Audit.compare(definition, row, :renewal), &(&1.field == :fixed_cast_time))
    end

    test "a negative source Range compares by its magnitude" do
      definition = %{@definition | range: 9}
      row = put_in(@matching_row["Range"], -9)

      refute Enum.any?(Audit.compare(definition, row, :renewal), &(&1.field == :range))
    end

    test "an Aesir weapon-range sentinel against a negative source Range is a finding" do
      definition = %{@definition | range: -1}
      row = put_in(@matching_row["Range"], -9)

      assert [%{field: :range, aesir: -1, source: source}] =
               Enum.filter(Audit.compare(definition, row, :renewal), &(&1.field == :range))

      assert source == List.duplicate(9, 10)
    end

    test "a source Vulture range flag must be declared as vulture_range" do
      row = put_in(@matching_row["Flags"], %{"AlterRangeVulture" => true})

      assert [%{field: :vulture_range, aesir: false, source: true}] =
               Enum.filter(
                 Audit.compare(@definition, row, :renewal),
                 &(&1.field == :vulture_range)
               )
    end

    test "a declared vulture_range matching the source flag is not a finding" do
      definition = %{@definition | vulture_range: true}
      row = put_in(@matching_row["Flags"], %{"AlterRangeVulture" => true})

      assert Audit.compare(definition, row, :renewal) == []

      refute Enum.any?(
               Audit.compare(@definition, @matching_row, :renewal),
               &(&1.field == :vulture_range)
             )
    end

    test "a source HitCount of 0 normalizes to 1 and matches Aesir's default hit_count" do
      row = Map.delete(@matching_row, "HitCount")

      refute Enum.any?(Audit.compare(@definition, row, :renewal), &(&1.field == :hit_count))
    end

    test "a negative source HitCount normalizes by magnitude and matches an equal Aesir value" do
      definition = %{@definition | hit_count: 3}
      row = Map.put(@matching_row, "HitCount", -3)

      refute Enum.any?(Audit.compare(definition, row, :renewal), &(&1.field == :hit_count))
    end

    test "a source HitCount that differs in magnitude from Aesir is a finding" do
      row = Map.put(@matching_row, "HitCount", 2)

      assert [%{field: :hit_count, aesir: 1, source: source}] =
               Enum.filter(Audit.compare(@definition, row, :renewal), &(&1.field == :hit_count))

      assert source == List.duplicate(2, 10)
    end

    test "a weapon-kind skill's source Weapon element matches Aesir's neutral default" do
      definition = %{@definition | damage_kind: :weapon}
      row = Map.put(@matching_row, "Element", "Weapon")

      refute Enum.any?(Audit.compare(definition, row, :renewal), &(&1.field == :element))
    end

    test "a magic-kind skill's source Weapon element still mismatches Aesir's neutral default" do
      definition = %{@definition | damage_kind: :magic}
      row = Map.put(@matching_row, "Element", "Weapon")

      assert Enum.any?(Audit.compare(definition, row, :renewal), &(&1.field == :element))
    end
  end

  describe "negative_hit_count_levels/2" do
    test "returns the negative raw values, unnormalized" do
      row = %{"HitCount" => -3}

      assert Audit.negative_hit_count_levels(row, 5) == [-3, -3, -3, -3, -3]
    end

    test "returns an empty list when HitCount is absent or non-negative" do
      assert Audit.negative_hit_count_levels(%{}, 5) == []
      assert Audit.negative_hit_count_levels(%{"HitCount" => 2}, 5) == []
    end
  end

  describe "suggest/3" do
    test "renders a plain option when only the current mode differs" do
      definition = %Definition{
        id: 5,
        name: :sm_bash,
        display_name: "Bash",
        max_level: 10,
        range: -1
      }

      findings = [%{field: :range, aesir: -1, source: 9}]

      suggestion = Audit.suggest(definition, findings, :renewal)

      assert suggestion == "```elixir\nrange: 9\n```"
    end

    test "renders a per-level integer sequence as a list, never as a charlist" do
      definition = %Definition{
        id: 5,
        name: :sm_bash,
        display_name: "Bash",
        max_level: 10,
        after_cast_delay: []
      }

      findings = [%{field: :after_cast_delay, aesir: [], source: List.duplicate(100, 10)}]

      suggestion = Audit.suggest(definition, findings, :renewal)

      assert suggestion =~ "after_cast_delay: [100, 100, 100, 100, 100, 100, 100, 100, 100, 100]"
    end

    test "renders a mode-keyed option's other-mode value as a list too" do
      definition = %Definition{
        id: 5,
        name: :sm_bash,
        display_name: "Bash",
        max_level: 10,
        after_cast_delay: [renewal: [], pre_renewal: List.duplicate(100, 3)]
      }

      findings = [%{field: :after_cast_delay, aesir: [], source: List.duplicate(50, 3)}]

      suggestion = Audit.suggest(definition, findings, :renewal)

      assert suggestion =~
               "after_cast_delay: [renewal: [50, 50, 50], pre_renewal: [100, 100, 100]]"
    end

    test "renders a mode-keyed option when the other mode's value differs from the source" do
      definition = %Definition{
        id: 5,
        name: :sm_bash,
        display_name: "Bash",
        max_level: 10,
        range: [renewal: -1, pre_renewal: 5]
      }

      findings = [%{field: :range, aesir: -1, source: 9}]

      suggestion = Audit.suggest(definition, findings, :renewal)

      assert suggestion == "```elixir\nrange: [renewal: 9, pre_renewal: 5]\n```"
    end
  end
end
