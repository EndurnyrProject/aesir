defmodule Mix.Tasks.Aesir.Import.RandomOptionsTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Aesir.Import.RandomOptions, as: Task

  @options [
    %{
      "Id" => 3,
      "Option" => "VAR_STRAMOUNT",
      "Script" => "bonus bStr,getrandomoptinfo(ROA_VALUE);"
    },
    %{
      "Id" => 4,
      "Option" => "VAR_AGIAMOUNT",
      "Script" => "bonus bAgi,getrandomoptinfo(ROA_VALUE);"
    }
  ]

  describe "options" do
    test "transpiles each script and keeps an inexpressible one without a program" do
      rows = @options ++ [%{"Id" => 9, "Option" => "ODD", "Script" => "bonus bNoSuchKey,1;"}]

      {options, [], report} = Task.convert(rows, [])

      assert [
               %{"id" => 3, "name" => "VAR_STRAMOUNT", "script" => str_script},
               %{"id" => 4},
               %{"id" => 9, "name" => "ODD", "script" => nil}
             ] = options

      assert str_script =~ "random_option(ctx, :value)"

      assert [{9, "ODD", {:unsupported, {:unknown_bonus_key, "bNoSuchKey"}}}] =
               report.unsupported_scripts
    end

    test "a repeated id merges, a taken name or a new row without a script is skipped" do
      rows =
        @options ++
          [
            %{"Id" => 3, "Script" => "bonus bVit,getrandomoptinfo(ROA_VALUE);"},
            %{"Id" => 5, "Option" => "VAR_AGIAMOUNT", "Script" => "bonus bInt,1;"},
            %{"Id" => 6, "Option" => "NO_SCRIPT"}
          ]

      {options, [], report} = Task.convert(rows, [])

      assert [%{"id" => 3, "name" => "VAR_STRAMOUNT", "script" => script}, %{"id" => 4}] = options
      assert script =~ ":vit"

      assert [{5, "duplicate option name VAR_AGIAMOUNT"}, {6, "missing Option or Script"}] =
               report.skipped_options
    end
  end

  describe "groups" do
    test "resolves option names and applies the entry defaults and corrections" do
      group = %{
        "Id" => 1,
        "Group" => "G1",
        "Slots" => [
          %{
            "Slot" => 1,
            "Options" => [%{"Option" => "VAR_STRAMOUNT", "MinValue" => 5, "MaxValue" => 2}]
          },
          %{
            "Slot" => 2,
            "Options" => [%{"Option" => "VAR_AGIAMOUNT", "Param" => 3, "Chance" => 700}]
          }
        ],
        "MaxRandom" => 9,
        "Random" => [
          %{"Option" => "VAR_AGIAMOUNT", "MinValue" => 1, "MaxValue" => 4, "Chance" => 10_000}
        ]
      }

      {_options, [out], _report} = Task.convert(@options, [group])

      assert out == %{
               "id" => 1,
               "name" => "G1",
               "slots" => [
                 [%{"option" => 3, "min" => 5, "max" => 6, "param" => 0, "chance" => 0}],
                 [%{"option" => 4, "min" => 0, "max" => 0, "param" => 3, "chance" => 700}]
               ],
               "max_random" => 5,
               "random" => [
                 %{"option" => 4, "min" => 1, "max" => 4, "param" => 0, "chance" => 10_000}
               ]
             }
    end

    test "a new group with an unknown option, a bad slot or a bad chance is dropped" do
      groups = [
        %{"Id" => 1, "Group" => "A", "Random" => [%{"Option" => "NOPE"}]},
        %{"Id" => 2, "Group" => "B", "Slots" => [%{"Slot" => 6, "Options" => []}]},
        %{
          "Id" => 3,
          "Group" => "C",
          "Random" => [%{"Option" => "VAR_STRAMOUNT", "Chance" => 10_001}]
        }
      ]

      {_options, [], report} = Task.convert(@options, groups)

      assert [{1, "unknown option NOPE"}, {2, "invalid slot 6"}, {3, "invalid chance 10001"}] =
               report.skipped_groups
    end

    test "a repeated id that fails part-way keeps what it applied before the failure" do
      groups = [
        %{"Id" => 1, "Group" => "G", "Random" => [%{"Option" => "VAR_STRAMOUNT"}]},
        %{
          "Id" => 1,
          "MaxRandom" => 2,
          "Random" => [%{"Option" => "VAR_AGIAMOUNT", "Param" => 200}, %{"Option" => "NOPE"}]
        }
      ]

      {_options, [out], report} = Task.convert(@options, groups)

      assert out["max_random"] == 2
      assert [%{"option" => 4, "param" => -56}] = out["random"]
      assert [{1, "unknown option NOPE"}] = report.skipped_groups
    end

    test "slots past the fifth are ignored" do
      slots = for n <- 1..6, do: %{"Slot" => n, "Options" => [%{"Option" => "VAR_STRAMOUNT"}]}

      {_options, [out], _report} =
        Task.convert(@options, [%{"Id" => 1, "Group" => "G", "Slots" => slots}])

      assert length(out["slots"]) == 5
    end

    test "slots not numbered 1..n abort the import" do
      slots = for n <- [1, 3], do: %{"Slot" => n, "Options" => [%{"Option" => "VAR_STRAMOUNT"}]}

      assert_raise Mix.Error, ~r/not 1..n/, fn ->
        Task.convert(@options, [%{"Id" => 1, "Group" => "G", "Slots" => slots}])
      end
    end
  end
end
