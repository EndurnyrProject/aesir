defmodule Aesir.ZoneServer.Mmo.ItemManagement.EquipScriptTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript

  defp on(refine, levels \\ []),
    do: Map.merge(%{refine: refine, base_level: 1, job_level: 1}, Map.new(levels))

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

    test "renders the level inputs as base_level(ctx)/job_level(ctx)" do
      program = [{:bonus, :atk, {:div, :base_level, 10}}, {:bonus, :matk, :job_level}]

      assert EquipScript.to_source(program) ==
               """
               ctx = bonus(ctx, :atk, div(base_level(ctx), 10))
               ctx = bonus(ctx, :matk, job_level(ctx))
               ctx
               """
               |> String.trim_trailing()
    end

    test "renders a ternary as an inline if expression" do
      program = [{:bonus, :str, {:ternary, {:>=, :refine, 7}, 3, 1}}]

      assert EquipScript.to_source(program) ==
               "bonus(ctx, :str, if((refine(ctx) >= 7), do: 3, else: 1))"
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
      tuple_skill_cooldown_dest: [{:bonus, {:skill_cooldown, 152}, -500}],
      tuple_skill_use_sp_dest: [{:bonus, {:skill_use_sp, 152}, -5}],
      tuple_skill_varcast_rate_dest: [{:bonus, {:skill_varcast_rate, 152}, -10}],
      mixed_flat_and_tuple: [
        {:bonus, :vit, 5},
        {:bonus, {:subele, :fire}, 10},
        {:bonus, :def, 3}
      ],
      tuple_dest_inside_if: [
        {:if, {:>=, :refine, 7}, [{:bonus, {:addrace, :brute}, 20}],
         [{:bonus, {:addrace, :all}, 5}]}
      ],
      tuple_add_eff_dest: [{:bonus, {:add_eff, :sc_stun}, 500}],
      tuple_add_eff2_dest: [{:bonus, {:add_eff2, :sc_curse}, 500}],
      tuple_add_eff_when_hit_dest: [{:bonus, {:add_eff_when_hit, :sc_poison}, 300}],
      tuple_res_eff_dest: [{:bonus, {:res_eff, :sc_freeze}, 1000}],
      tuple_magic_addclass_dest: [{:bonus, {:magic_addclass, :boss}, 30}],
      tuple_race2_dest: [{:bonus, {:addrace2, :biolab}, 20}],
      tuple_item_heal_dest: [{:bonus, {:add_item_heal, 501}, 10}],
      tuple_ignore_def_class_dest: [{:bonus, {:ignore_def_class, :normal}, 100}],
      flat_defender_keys: [{:bonus, :long_atk_def, 10}, {:bonus, :hp_gain_value, 50}],
      set_def_ele_dest: [{:set, :def_ele, :holy}],
      pair_sp_drain_dest: [{:bonus, :sp_drain_rate, 30}, {:bonus, :sp_drain_percent, 2}],
      pair_dest: [{:bonus, :hp_drain_rate, 50}, {:bonus, :hp_drain_percent, 5}],
      splash_dest: [{:bonus, :splash_range, 1}],
      set_dest: [{:set, :atk_ele, :fire}],
      set_mixed_with_bonus: [{:bonus, :atk, 10}, {:set, :atk_ele, :wind}],
      set_inside_if: [
        {:if, {:>=, :refine, 7}, [{:set, :atk_ele, :holy}], [{:set, :atk_ele, :neutral}]}
      ],
      base_level_expr: [{:bonus, :atk, {:div, :base_level, 10}}],
      job_level_expr: [{:bonus, :matk, :job_level}],
      base_level_gate: [{:if, {:>, :base_level, 99}, [{:bonus, :max_hp, 500}], []}],
      ternary_expr: [{:bonus, :str, {:ternary, {:>=, :refine, 7}, 3, 1}}],
      nested_ternary: [
        {:bonus, :hit, {:ternary, {:<, :refine, 7}, 1, {:ternary, {:<, :refine, 9}, 2, 3}}}
      ],
      ternary_on_levels: [
        {:bonus, :critical, {:ternary, {:>, :base_level, 99}, :refine, {:div, :refine, 2}}}
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

  describe "corpus round-trip over the imported equip.yml" do
    test "every on_equip program round-trips through to_source |> parse! and evals cleanly for refine 0..20" do
      programs =
        ItemManagement.get_all_items()
        |> Enum.filter(&(&1.on_equip != nil))
        |> Enum.map(& &1.on_equip)

      assert programs != []

      for program <- programs do
        assert program |> EquipScript.to_source() |> EquipScript.parse!() == program

        for refine <- 0..20, levels <- [[], [base_level: 200, job_level: 70]] do
          assert is_map(EquipScript.eval(program, on(refine, levels)))
        end
      end
    end
  end

  describe "break/unbreakable bonus keys" do
    test "parses and evaluates a break-rate bonus" do
      program = EquipScript.parse!("bonus(ctx, :break_weapon_rate, 50)")

      assert program == [{:bonus, :break_weapon_rate, 50}]
      assert EquipScript.eval(program, on(0)) == %{break_weapon_rate: 50}
    end

    test "parses and evaluates an unbreakable bonus" do
      program = EquipScript.parse!("bonus(ctx, :unbreakable_weapon, 1)")

      assert program == [{:bonus, :unbreakable_weapon, 1}]
      assert EquipScript.eval(program, on(0)) == %{unbreakable_weapon: 1}
    end
  end

  describe "capacity and rate bonus keys" do
    test "evaluates the hp/sp capacity keys" do
      program =
        EquipScript.parse!("""
        ctx = bonus(ctx, :max_hp, 800)
        ctx = bonus(ctx, :max_hp_rate, 5)
        ctx = bonus(ctx, :max_sp, 50)
        ctx = bonus(ctx, :max_sp_rate, 3)
        ctx
        """)

      assert EquipScript.eval(program, on(0)) == %{
               max_hp: 800,
               max_hp_rate: 5,
               max_sp: 50,
               max_sp_rate: 3
             }
    end

    test "evaluates the rate and all-stats keys" do
      program =
        EquipScript.parse!("""
        ctx = bonus(ctx, :aspd_rate, 10)
        ctx = bonus(ctx, :atk_rate, 5)
        ctx = bonus(ctx, :matk_rate, 7)
        ctx = bonus(ctx, :all_stats, 2)
        ctx
        """)

      assert EquipScript.eval(program, on(0)) == %{
               aspd_rate: 10,
               atk_rate: 5,
               matk_rate: 7,
               all_stats: 2
             }
    end

    test "repeated capacity bonuses sum within one program" do
      program =
        EquipScript.parse!("ctx = bonus(ctx, :max_hp, 300)\nctx = bonus(ctx, :max_hp, 200)\nctx")

      assert EquipScript.eval(program, on(0)) == %{max_hp: 500}
    end
  end

  describe ":set instructions" do
    test "stores the constant rather than summing it" do
      program = EquipScript.parse!("set(ctx, :atk_ele, :fire)")

      assert program == [{:set, :atk_ele, :fire}]
      assert EquipScript.eval(program, on(0)) == %{atk_ele: :fire}
    end

    test "the last set wins within one program" do
      program =
        EquipScript.parse!(
          "ctx = set(ctx, :atk_ele, :fire)\nctx = set(ctx, :atk_ele, :wind)\nctx"
        )

      assert EquipScript.eval(program, on(0)) == %{atk_ele: :wind}
    end

    test "a refine-gated set resolves to the taken branch" do
      program =
        EquipScript.parse!("""
        if (refine(ctx) >= 7) do
          set(ctx, :atk_ele, :holy)
        else
          set(ctx, :atk_ele, :neutral)
        end
        """)

      assert EquipScript.eval(program, on(9)) == %{atk_ele: :holy}
      assert EquipScript.eval(program, on(0)) == %{atk_ele: :neutral}
    end

    test "raises on a set destination outside the value vocabulary" do
      assert_raise ArgumentError, fn -> EquipScript.parse!("set(ctx, :atk, :fire)") end
    end

    test "raises on a set value outside the destination's domain" do
      assert_raise ArgumentError, fn -> EquipScript.parse!("set(ctx, :atk_ele, :brute)") end
    end

    test "raises on a non-atom set value" do
      assert_raise ArgumentError, fn -> EquipScript.parse!("set(ctx, :atk_ele, 3)") end
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

    test "raises on a status tuple dest with an out-of-domain atom param" do
      assert_raise ArgumentError, fn ->
        EquipScript.parse!("bonus(ctx, {:add_eff, :sc_bogus}, 500)")
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

      assert EquipScript.eval(program, on(5)) == %{smatk: 3}
    end

    test "an if gate is off below the threshold and on at or above it" do
      program = [{:if, {:>=, :refine, 9}, [{:bonus, :matk, 20}], []}]

      assert EquipScript.eval(program, on(8)) == %{}
      assert EquipScript.eval(program, on(9)) == %{matk: 20}
    end

    test "evaluates the else branch when the gate is false" do
      program = [{:if, {:>=, :refine, 9}, [{:bonus, :matk, 20}], [{:bonus, :matk, 5}]}]

      assert EquipScript.eval(program, on(3)) == %{matk: 5}
    end

    test "accumulates repeated bonus instructions into one key" do
      program = [{:bonus, :str, 2}, {:bonus, :str, {:div, :refine, 2}}]

      assert EquipScript.eval(program, on(6)) == %{str: 5}
    end

    test "a non-stackable destination keeps the largest contribution" do
      program = [{:bonus, :movement_speed, 25}, {:bonus, :movement_speed, 10}]

      assert EquipScript.eval(program, on(0)) == %{movement_speed: 25}
      assert EquipScript.eval(Enum.reverse(program), on(0)) == %{movement_speed: 25}
    end

    test "splash range keeps the largest contribution instead of summing" do
      program = [{:bonus, :splash_range, 1}, {:bonus, :splash_range, 1}]

      assert EquipScript.eval(program, on(0)) == %{splash_range: 1}
    end

    test "both HP drain halves sum independently" do
      program = [
        {:bonus, :hp_drain_rate, 50},
        {:bonus, :hp_drain_percent, 5},
        {:bonus, :hp_drain_rate, 30},
        {:bonus, :hp_drain_percent, 1}
      ]

      assert EquipScript.eval(program, on(0)) == %{hp_drain_rate: 80, hp_drain_percent: 6}
    end

    test "sums repeated tuple destinations into one key" do
      program = [
        {:bonus, {:addrace, :brute}, 20},
        {:bonus, {:addrace, :brute}, 5},
        {:bonus, {:addrace, :undead}, 15}
      ]

      assert EquipScript.eval(program, on(0)) == %{
               {:addrace, :brute} => 25,
               {:addrace, :undead} => 15
             }
    end

    test "refine 0 yields zeros and gates stay closed" do
      program = [
        {:bonus, :critical, :refine},
        {:if, {:>, :refine, 0}, [{:bonus, :matk, 10}], []}
      ]

      assert EquipScript.eval(program, on(0)) == %{critical: 0}
    end

    test "evaluates logical conditions" do
      program = [{:if, {:and, {:>, :refine, 3}, {:<, :refine, 9}}, [{:bonus, :str, 1}], []}]

      assert EquipScript.eval(program, on(5)) == %{str: 1}
      assert EquipScript.eval(program, on(10)) == %{}
    end

    test "raises on an unrecognized expression node" do
      assert_raise ArgumentError, fn ->
        EquipScript.eval([{:bonus, :str, {:mod, :refine, 2}}], on(5))
      end
    end

    test "level inputs feed expressions and gates" do
      program = [
        {:bonus, :atk, {:div, :base_level, 10}},
        {:if, {:>, :job_level, 50}, [{:bonus, :matk, 15}], []}
      ]

      assert EquipScript.eval(program, on(0, base_level: 175, job_level: 60)) ==
               %{atk: 17, matk: 15}

      assert EquipScript.eval(program, on(0, base_level: 40, job_level: 10)) == %{atk: 4}
    end

    test "a ternary picks its branch from the condition" do
      program = [{:bonus, :str, {:ternary, {:>=, :refine, 7}, 3, 1}}]

      assert EquipScript.eval(program, on(7)) == %{str: 3}
      assert EquipScript.eval(program, on(6)) == %{str: 1}
    end

    test "nested ternaries resolve innermost-first" do
      program = [
        {:bonus, :hit, {:ternary, {:<, :refine, 7}, 1, {:ternary, {:<, :refine, 9}, 2, 3}}}
      ]

      assert EquipScript.eval(program, on(0)) == %{hit: 1}
      assert EquipScript.eval(program, on(8)) == %{hit: 2}
      assert EquipScript.eval(program, on(12)) == %{hit: 3}
    end

    test "raises when a program reads an input the map lacks" do
      assert_raise KeyError, fn ->
        EquipScript.eval([{:bonus, :atk, :base_level}], %{refine: 0})
      end
    end
  end
end
