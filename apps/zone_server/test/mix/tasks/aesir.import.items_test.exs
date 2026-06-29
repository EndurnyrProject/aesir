defmodule Mix.Tasks.Aesir.Import.ItemsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Mix.Tasks.Aesir.Import.Items

  defp definition(attrs) do
    struct(
      ItemDefinition,
      Map.merge(%{id: 501, aegis_name: "Red_Potion", name: "Red Potion"}, attrs)
    )
  end

  describe "build_report/1" do
    test "renders an empty-state line when there are no failures" do
      report = Items.build_report([])

      assert report =~ "All usable item scripts transpiled"
      refute report =~ "| id |"
    end

    test "renders a markdown table with one row per failure" do
      failures = [
        {501, "Red Potion", {:unsupported, "produce"}},
        {502, "Orange Potion", {:parse_error, :eof}}
      ]

      report = Items.build_report(failures)

      assert report =~ "| id | name | reason |"
      assert report =~ "| 501 | Red Potion | {:unsupported, \"produce\"} |"
      assert report =~ "| 502 | Orange Potion | {:parse_error, :eof} |"
    end
  end

  describe "apply_transpile/2" do
    test "sets on_use from a supported usable script" do
      assert {%ItemDefinition{on_use: "heal(ctx, hp: 45)"}, nil} =
               Items.apply_transpile(definition(%{type: :usable}), "itemheal 45,0;")
    end

    test "keeps on_use nil and records a failure for an unsupported script" do
      assert {%ItemDefinition{on_use: nil}, {501, "Red Potion", {:unsupported, _}}} =
               Items.apply_transpile(definition(%{type: :usable}), "produce 1;")
    end

    test "skips non-usable types" do
      assert {%ItemDefinition{on_use: nil}, nil} =
               Items.apply_transpile(definition(%{type: :etc}), "itemheal 45,0;")
    end

    test "skips usable items without a script" do
      assert {%ItemDefinition{on_use: nil}, nil} =
               Items.apply_transpile(definition(%{type: :usable}), nil)
    end
  end
end
