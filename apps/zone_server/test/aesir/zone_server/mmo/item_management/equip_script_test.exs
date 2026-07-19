defmodule Aesir.ZoneServer.Mmo.ItemManagement.EquipScriptTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript

  describe "to_source/1" do
    test "renders a single bonus instruction as a bare DSL call" do
      assert EquipScript.to_source([{:bonus, :smatk, 3}]) == "bonus(ctx, :smatk, 3)"
    end

    test "renders multiple instructions as ctx rebinds returning ctx" do
      program = [{:bonus, :vit, 5}, {:bonus, :def, 10}]

      assert EquipScript.to_source(program) ==
               """
               ctx = bonus(ctx, :vit, 5)
               ctx = bonus(ctx, :def, 10)
               ctx
               """
               |> String.trim_trailing()
    end

    test "renders :refine as refine(ctx) and arithmetic with div/2" do
      program = [{:bonus, :smatk, {:+, 1, {:div, :refine, 2}}}]

      assert EquipScript.to_source(program) ==
               "bonus(ctx, :smatk, (1 + div(refine(ctx), 2)))"
    end

    test "renders an if instruction with an empty else branch as ctx" do
      program = [{:if, {:>=, :refine, 9}, [{:bonus, :matk, 20}], []}]

      assert EquipScript.to_source(program) ==
               """
               if (refine(ctx) >= 9) do
                 bonus(ctx, :matk, 20)
               else
                 ctx
               end
               """
               |> String.trim_trailing()
    end

    test "renders logical conditions with && and ||" do
      program = [
        {:if, {:and, {:>, :refine, 3}, {:<, :refine, 9}}, [{:bonus, :str, 1}], []}
      ]

      assert EquipScript.to_source(program) =~
               "if ((refine(ctx) > 3) && (refine(ctx) < 9)) do"
    end
  end

  describe "to_source |> parse! round-trip" do
    programs = [
      flat: [{:bonus, :smatk, 3}, {:bonus, :spl, 2}, {:bonus, :crt, 2}],
      refine_expr: [{:bonus, :smatk, {:+, 1, {:div, :refine, 2}}}],
      arithmetic: [{:bonus, :atk, {:*, {:-, :refine, 1}, 3}}],
      negative: [{:bonus, :agi, -1}, {:bonus, :mdef, {:+, -5, :refine}}],
      refine_leaf: [{:bonus, :critical, :refine}],
      nested_if: [
        {:bonus, :mdef, 10},
        {:if, {:>, :refine, 7}, [{:bonus, :matk, 20}], [{:bonus, :matk, 5}]}
      ],
      multi_branch: [
        {:if, {:>=, :refine, 7}, [{:bonus, :atk, 30}, {:bonus, :hit, 5}], []}
      ],
      logical: [
        {:if, {:or, {:>=, :refine, 9}, {:==, :refine, 0}}, [{:bonus, :res, 15}], []}
      ],
      tuple_dest: [{:bonus, {:addrace, :brute}, 20}],
      tuple_skill_dest: [{:bonus, {:skill_atk, 152}, 30}],
      mixed_flat_and_tuple: [
        {:bonus, :vit, 5},
        {:bonus, {:subele, :fire}, 10},
        {:bonus, :def, 3}
      ],
      tuple_dest_inside_if: [
        {:if, {:>=, :refine, 7}, [{:bonus, {:addrace, :brute}, 20}],
         [{:bonus, {:addrace, :all}, 5}]}
      ]
    ]

    for {name, program} <- programs do
      test "is identity for #{name}" do
        program = unquote(Macro.escape(program))
        assert program |> EquipScript.to_source() |> EquipScript.parse!() == program
      end

      test "is identity for #{name} through a YAML round-trip" do
        program = unquote(Macro.escape(program))

        parsed =
          program
          |> EquipScript.to_source()
          |> then(&Ymlr.document!(%{"on_equip" => &1}))
          |> YamlElixir.read_from_string!()
          |> Map.fetch!("on_equip")
          |> EquipScript.parse!()

        assert parsed == program
      end
    end
  end

  describe "break/unbreakable bonus keys" do
    test "parses and evaluates a break-rate bonus" do
      program = EquipScript.parse!("bonus(ctx, :break_weapon_rate, 50)")

      assert program == [{:bonus, :break_weapon_rate, 50}]
      assert EquipScript.eval(program, 0) == %{break_weapon_rate: 50}
    end

    test "parses and evaluates an unbreakable bonus" do
      program = EquipScript.parse!("bonus(ctx, :unbreakable_weapon, 1)")

      assert program == [{:bonus, :unbreakable_weapon, 1}]
      assert EquipScript.eval(program, 0) == %{unbreakable_weapon: 1}
    end
  end

  describe "parse!/1 strictness" do
    test "raises on a call outside the vocabulary" do
      assert_raise ArgumentError, fn ->
        EquipScript.parse!("heal(ctx, hp: 10)")
      end
    end

    test "raises on an unknown bonus destination" do
      assert_raise ArgumentError, fn ->
        EquipScript.parse!("bonus(ctx, :maxhp, 10)")
      end
    end

    test "raises on an out-of-vocabulary expression" do
      assert_raise ArgumentError, fn ->
        EquipScript.parse!("bonus(ctx, :smatk, rem(refine(ctx), 2))")
      end
    end

    test "raises on a malformed bonus arity" do
      assert_raise ArgumentError, fn ->
        EquipScript.parse!("bonus(ctx, :smatk)")
      end
    end

    test "raises when a comparison sits where an expression is expected" do
      assert_raise ArgumentError, fn ->
        EquipScript.parse!("bonus(ctx, :smatk, refine(ctx) > 2)")
      end
    end

    test "raises on unparseable source" do
      assert_raise TokenMissingError, fn ->
        EquipScript.parse!("bonus(ctx, :smatk,")
      end
    end

    test "raises on a tuple dest with an unknown family" do
      assert_raise ArgumentError, fn ->
        EquipScript.parse!("bonus(ctx, {:bogus_family, :brute}, 20)")
      end
    end

    test "raises on a tuple dest with an out-of-domain atom param" do
      assert_raise ArgumentError, fn ->
        EquipScript.parse!("bonus(ctx, {:addrace, :bogus}, 20)")
      end
    end

    test "raises on a tuple dest with a non-positive skill id" do
      assert_raise ArgumentError, fn ->
        EquipScript.parse!("bonus(ctx, {:skill_atk, 0}, 20)")
      end
    end

    test "raises on a 3-element tuple dest" do
      assert_raise ArgumentError, fn ->
        EquipScript.parse!("bonus(ctx, {:addrace, :brute, :extra}, 20)")
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

    test "sums repeated tuple destinations into one key" do
      program = [
        {:bonus, {:addrace, :brute}, 20},
        {:bonus, {:addrace, :brute}, 5},
        {:bonus, {:addrace, :undead}, 15}
      ]

      assert EquipScript.eval(program, 0) == %{
               {:addrace, :brute} => 25,
               {:addrace, :undead} => 15
             }
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
