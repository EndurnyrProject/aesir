defmodule Aesir.ZoneServer.Mmo.StatusEffect.CalcFlagsTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.CalcFlags
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects

  test "an empty source selection is valid but a missing supported identity is not" do
    rows = [%{"id" => "sc_example", "flags" => [], "scripted" => false, "available" => true}]
    definition = %{id: :sc_example, target_types: [:mob], engine_only: false}

    assert CalcFlags.build_index!(rows, [definition]) == %{"sc_example" => []}

    assert_raise ArgumentError, ~r/sc_missing/, fn ->
      CalcFlags.build_index!(rows, [%{definition | id: :sc_missing}])
    end

    assert_raise ArgumentError, ~r/flag/, fn ->
      CalcFlags.build_index!([%{"id" => "sc_example", "flags" => ["made_up"]}], [])
    end
  end

  test "malformed admission facts fail validation before a monster can apply the status" do
    row = %{"id" => "sc_example", "flags" => [], "scripted" => false, "available" => true}

    for malformed <- [
          Map.put(row, "available", "false"),
          Map.put(row, "scripted", "false"),
          Map.delete(row, "available"),
          Map.delete(row, "scripted")
        ] do
      assert_raise ArgumentError, ~r/admission/, fn ->
        CalcFlags.build_index!([malformed], [])
      end
    end
  end

  test "both shipped catalogs classify every supported monster identity" do
    definitions = Enum.map(Effects.all(), & &1.metadata())

    for directory <- ["re", "pre-re"] do
      path = Application.app_dir(:zone_server, "priv/db/#{directory}/status_calc_flags.yml")
      rows = YamlElixir.read_from_file!(path)
      selections = CalcFlags.build_index!(rows, definitions)
      CalcFlags.validate_aliases!(Map.keys(selections))
      assert map_size(selections) > length(definitions)
    end
  end

  test "explicit source events retain their canonical selections" do
    assert CalcFlags.for_event(:sc_intravision, :removed) == ["All"]
    assert CalcFlags.for_event(:sc_intravision, :apply) == []

    expected = if GameMode.mode() == :pre_renewal, do: ["Matk"], else: []
    assert CalcFlags.for_event(:sc_magicpower, :armed) == expected
    assert CalcFlags.for_event(:sc_blessing, :armed) == []
  end
end
