defmodule Aesir.ZoneServer.Mmo.DefinitionValidationTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.DefinitionValidation

  @schema %{
    id: {:required, :atom},
    level: {:integer, {:gt, 0}}
  }

  describe "validate!/4" do
    test "returns validated map merged over defaults" do
      result = DefinitionValidation.validate!(@schema, [id: :foo], __MODULE__, %{level: 1})

      assert result == %{id: :foo, level: 1}
    end

    test "declared values win over defaults" do
      result =
        DefinitionValidation.validate!(@schema, [id: :foo, level: 5], __MODULE__, %{level: 1})

      assert result == %{id: :foo, level: 5}
    end

    test "raises naming the module when a required key is missing" do
      assert_raise ArgumentError, ~r/DefinitionValidationTest.*id/s, fn ->
        DefinitionValidation.validate!(@schema, [level: 3], __MODULE__)
      end
    end

    test "raises naming the field when a value is invalid" do
      assert_raise ArgumentError, ~r/level/, fn ->
        DefinitionValidation.validate!(@schema, [id: :foo, level: 0], __MODULE__)
      end
    end

    test "raises on unknown keys" do
      assert_raise ArgumentError, ~r/unknown.*:bogus/is, fn ->
        DefinitionValidation.validate!(@schema, [id: :foo, bogus: 1], __MODULE__)
      end
    end
  end

  describe "check_unknown_keys!/3" do
    test "returns :ok when all keys are known" do
      assert :ok = DefinitionValidation.check_unknown_keys!(@schema, %{id: :foo}, __MODULE__)
    end

    test "raises listing the unknown keys and module" do
      assert_raise ArgumentError, ~r/DefinitionValidationTest.*:nope/s, fn ->
        DefinitionValidation.check_unknown_keys!(@schema, %{id: :foo, nope: 1}, __MODULE__)
      end
    end
  end
end
