defmodule Aesir.ZoneServer.Mmo.ItemManagement.EquipScriptTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript

  describe "encode/1" do
    test "encodes a flat bonus instruction to a YAML-safe list" do
      assert EquipScript.encode([{:bonus, :smatk, 3}]) == [["bonus", "smatk", 3]]
    end

    test "encodes :refine as a string and arithmetic as a nested list" do
      program = [{:bonus, :smatk, {:+, 1, {:div, :refine, 2}}}]

      assert EquipScript.encode(program) == [
               ["bonus", "smatk", ["add", 1, ["div", "refine", 2]]]
             ]
    end

    test "encodes an if instruction with a condition and branches" do
      program = [
        {:if, {:>=, :refine, 9}, [{:bonus, :matk, 20}], []}
      ]

      assert EquipScript.encode(program) == [
               ["if", [">=", "refine", 9], [["bonus", "matk", 20]], []]
             ]
    end

    test "encodes logical conditions" do
      program = [
        {:if, {:and, {:>, :refine, 3}, {:<, :refine, 9}}, [{:bonus, :str, 1}], []}
      ]

      assert EquipScript.encode(program) == [
               ["if", ["and", [">", "refine", 3], ["<", "refine", 9]], [["bonus", "str", 1]], []]
             ]
    end
  end

  describe "encode |> decode! round-trip" do
    programs = [
      flat: [{:bonus, :smatk, 3}, {:bonus, :spl, 2}, {:bonus, :crt, 2}],
      refine_expr: [{:bonus, :smatk, {:+, 1, {:div, :refine, 2}}}],
      arithmetic: [{:bonus, :atk, {:*, {:-, :refine, 1}, 3}}],
      refine_leaf: [{:bonus, :critical, :refine}],
      nested_if: [
        {:bonus, :mdef, 10},
        {:if, {:>, :refine, 7}, [{:bonus, :matk, 20}], [{:bonus, :matk, 5}]}
      ],
      logical: [
        {:if, {:or, {:>=, :refine, 9}, {:==, :refine, 0}}, [{:bonus, :res, 15}], []}
      ]
    ]

    for {name, program} <- programs do
      test "is identity for #{name}" do
        program = unquote(Macro.escape(program))
        assert program |> EquipScript.encode() |> EquipScript.decode!() == program
      end

      test "is identity for #{name} through a YAML round-trip" do
        program = unquote(Macro.escape(program))

        decoded =
          program
          |> EquipScript.encode()
          |> then(&Ymlr.document!(%{"on_equip" => &1}))
          |> YamlElixir.read_from_string!()
          |> Map.fetch!("on_equip")
          |> EquipScript.decode!()

        assert decoded == program
      end
    end
  end

  describe "decode!/1 strictness" do
    test "raises on an unknown operator string" do
      assert_raise ArgumentError, fn ->
        EquipScript.decode!([["bonus", "smatk", ["mod", "refine", 2]]])
      end
    end

    test "raises on an unknown destination string" do
      assert_raise ArgumentError, fn ->
        EquipScript.decode!([["bonus", "maxhp", 10]])
      end
    end

    test "raises on an unknown statement tag" do
      assert_raise ArgumentError, fn ->
        EquipScript.decode!([["whenever", [">", "refine", 1], [], []]])
      end
    end

    test "raises on a malformed shape" do
      assert_raise ArgumentError, fn ->
        EquipScript.decode!([["bonus", "smatk"]])
      end
    end

    test "raises when a comparison op sits where an expression is expected" do
      assert_raise ArgumentError, fn ->
        EquipScript.decode!([["bonus", "smatk", [">", "refine", 2]]])
      end
    end
  end

  describe "eval/2" do
    test "evaluates integer-truncating arithmetic against refine" do
      program = [{:bonus, :smatk, {:+, 1, {:div, :refine, 2}}}]

      assert EquipScript.eval(program, 5) == %{smatk: 3}
    end

    test "an if gate is off below the threshold and on at or above it" do
      program = [{:if, {:>=, :refine, 9}, [{:bonus, :matk, 20}], []}]

      assert EquipScript.eval(program, 8) == %{}
      assert EquipScript.eval(program, 9) == %{matk: 20}
    end

    test "evaluates the else branch when the gate is false" do
      program = [{:if, {:>=, :refine, 9}, [{:bonus, :matk, 20}], [{:bonus, :matk, 5}]}]

      assert EquipScript.eval(program, 3) == %{matk: 5}
    end

    test "accumulates repeated bonus instructions into one key" do
      program = [{:bonus, :str, 2}, {:bonus, :str, {:div, :refine, 2}}]

      assert EquipScript.eval(program, 6) == %{str: 5}
    end

    test "refine 0 yields zeros and gates stay closed" do
      program = [
        {:bonus, :critical, :refine},
        {:if, {:>, :refine, 0}, [{:bonus, :matk, 10}], []}
      ]

      assert EquipScript.eval(program, 0) == %{critical: 0}
    end

    test "evaluates logical conditions" do
      program = [{:if, {:and, {:>, :refine, 3}, {:<, :refine, 9}}, [{:bonus, :str, 1}], []}]

      assert EquipScript.eval(program, 5) == %{str: 1}
      assert EquipScript.eval(program, 10) == %{}
    end

    test "raises on an unrecognized expression node" do
      assert_raise ArgumentError, fn ->
        EquipScript.eval([{:bonus, :str, {:mod, :refine, 2}}], 5)
      end
    end
  end
end
