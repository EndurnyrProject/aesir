defmodule Aesir.ZoneServer.Mmo.Skill.DefinitionTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @required_opts [
    id: 1,
    name: :test_skill,
    display_name: "Test Skill",
    max_level: 5
  ]

  describe "target_type" do
    test "accepts :target_corpse" do
      defn = Definition.build!(@required_opts ++ [target_type: :target_corpse], __MODULE__)
      assert defn.target_type == :target_corpse
    end

    test "accepts :target_any" do
      defn = Definition.build!(@required_opts ++ [target_type: :target_any], __MODULE__)
      assert defn.target_type == :target_any
    end

    test "rejects an invalid target_type" do
      assert_raise ArgumentError, ~r/DefinitionTest/, fn ->
        Definition.build!(@required_opts ++ [target_type: :bogus_target], __MODULE__)
      end
    end
  end

  describe "damage_kind" do
    test "defaults to :weapon when omitted" do
      defn = Definition.build!(@required_opts, __MODULE__)
      assert defn.damage_kind == :weapon
    end

    test "accepts :magic" do
      defn = Definition.build!(@required_opts ++ [damage_kind: :magic], __MODULE__)
      assert defn.damage_kind == :magic
    end

    test "accepts :misc" do
      defn = Definition.build!(@required_opts ++ [damage_kind: :misc], __MODULE__)
      assert defn.damage_kind == :misc
    end

    test "rejects an invalid value" do
      assert_raise ArgumentError, ~r/DefinitionTest/, fn ->
        Definition.build!(@required_opts ++ [damage_kind: :bogus], __MODULE__)
      end
    end
  end

  describe "fixed_cast_time" do
    test "defaults to [] when omitted" do
      defn = Definition.build!(@required_opts, __MODULE__)
      assert defn.fixed_cast_time == []
    end

    test "accepts a list of integers" do
      defn = Definition.build!(@required_opts ++ [fixed_cast_time: [200, 200]], __MODULE__)
      assert defn.fixed_cast_time == [200, 200]
    end
  end
end
