defmodule Aesir.ZoneServer.Mmo.MobManagement.ImporterTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.Importer

  defp entry(overrides) do
    Map.merge(%{"Id" => 1001, "AegisName" => "TEST", "Name" => "Test Mob"}, overrides)
  end

  describe "to_definition/1 mode derivation" do
    test "an Ai type that decodes to MD_AGGRESSIVE yields :aggressive" do
      {:ok, definition} = Importer.to_definition(entry(%{"Ai" => 4}))

      assert :aggressive in definition.modes
    end

    test "a boss class still yields :boss" do
      {:ok, definition} = Importer.to_definition(entry(%{"Class" => "Boss"}))

      assert :boss in definition.modes
    end

    test "boss + aggressive-decoding Ai + explicit aggressive dedup" do
      {:ok, definition} =
        Importer.to_definition(
          entry(%{"Class" => "Boss", "Ai" => 4, "Modes" => %{"Aggressive" => true}})
        )

      assert Enum.count(definition.modes, &(&1 == :aggressive)) == 1
      assert Enum.count(definition.modes, &(&1 == :boss)) == 1
      assert definition.modes == Enum.uniq(definition.modes)
    end

    test "a non-aggressive Ai type (6, empty bitmask) yields no derived modes" do
      {:ok, definition} = Importer.to_definition(entry(%{"Ai" => 6}))

      assert definition.modes == []
    end

    test "missing Ai defaults to no derived modes" do
      {:ok, definition} = Importer.to_definition(entry(%{}))

      assert definition.modes == []
    end
  end
end
