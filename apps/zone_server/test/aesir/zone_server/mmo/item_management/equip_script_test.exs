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
      tuple_add_eff_duration_dest: [
        {:bonus, {:add_eff, {:sc_stun, 93}}, 500},
        {:bonus, {:add_eff_duration, {:sc_stun, 93}}, 5_000}
      ],
      tuple_vanish_battle_dest: [
        {:bonus, {:sp_vanish_rate, 849}, 80},
        {:bonus, {:sp_vanish_percent, 849}, 30}
      ],
      tuple_vanish_race_dest: [
        {:bonus, {:hp_vanish_race_rate, :player_human}, 1_000},
        {:bonus, {:hp_vanish_race_percent, :player_human}, 8}
      ],
      tuple_defender_proc_dest: [
        {:bonus, {:def_set_race_rate, :player_human}, 10_000},
        {:bonus, {:def_set_race_duration, :player_human}, 5_000},
        {:bonus, {:def_set_race_value, :player_human}, 1}
      ],
      tuple_add_eff2_dest: [{:bonus, {:add_eff2, :sc_curse}, 500}],
      tuple_add_eff_when_hit_dest: [{:bonus, {:add_eff_when_hit, :sc_poison}, 300}],
      tuple_res_eff_dest: [{:bonus, {:res_eff, :sc_freeze}, 1000}],
      tuple_magic_addclass_dest: [{:bonus, {:magic_addclass, :boss}, 30}],
      tuple_race2_dest: [{:bonus, {:addrace2, :biolab}, 20}],
      tuple_item_heal_dest: [{:bonus, {:add_item_heal, 501}, 10}],
      tuple_item_group_heal_dest: [{:bonus, {:add_item_group_heal, :food}, 10}],
      tuple_coma_class_dest: [{:bonus, {:coma_class, :boss}, 250}],
      paired_get_zeny_dest: [{:paired_choice, :get_zeny, 100, 25}],
      flat_hit_rate: [{:bonus, :hit_rate, 15}],
      flat_movement_speed_add: [{:bonus, :movement_speed_add, 20}],
      flat_critical_long: [{:bonus, :critical_long, 7}],
      flat_no_regen: [{:bonus, :no_regen, 3}],
      tuple_ignore_def_class_dest: [{:bonus, {:ignore_def_class, :normal}, 100}],
      tuple_ignore_def_class_rate_dest: [{:bonus, {:ignore_def_class, :boss}, 50}],
      tuple_magic_addrace2_dest: [{:bonus, {:magic_addrace2, :goblin}, 20}],
      tuple_hp_regen_interval_dest: [{:bonus, {:hp_regen_bonus, 10_000}, 5}],
      tuple_hp_loss_interval_dest: [{:bonus, {:hp_loss_bonus, 5_000}, 10}],
      flat_sp_gain_value: [{:bonus, :sp_gain_value, 5}],
      flat_heal_power2: [{:bonus, :heal_power2, 10}],
      flat_perfect_hit_rate: [{:bonus, :perfect_hit_rate, 25}],
      tuple_skill_heal_dest: [{:bonus, {:skill_heal, 28}, 3}],
      flat_magic_hp_gain_value: [{:bonus, :magic_hp_gain_value, 30}],
      tuple_ignore_mdef_class_dest: [{:bonus, {:ignore_mdef_class, :boss}, 50}],
      tuple_subrace2_dest: [{:bonus, {:subrace2, :goblin}, 15}],
      tuple_monster_drop_dest: [{:bonus, {:add_monster_drop, 519}, 100}],
      tuple_monster_drop_race_dest: [{:bonus, {:add_monster_drop, 517, :brute}, 3000}],
      flat_magic_sp_gain_value: [{:bonus, :magic_sp_gain_value, 20}],
      flat_long_sp_gain_value: [{:bonus, :long_sp_gain_value, 15}],
      tuple_sp_regen_interval_dest: [{:bonus, {:sp_regen_bonus, 10_000}, 3}],
      tuple_sp_loss_interval_dest: [{:bonus, {:sp_loss_bonus, 4_000}, 2}],
      tuple_add_damage_class_dest: [{:bonus, {:add_damage_class, 1917}, 10}],
      tuple_add_def_monster_dest: [{:bonus, {:add_def_monster, 1917}, 10}],
      tuple_monster_drop_group_dest: [{:bonus, {:add_monster_drop_group, :food}, 10_000}],
      tuple_sp_gain_race_dest: [{:bonus, {:sp_gain_race, :undead}, 3}],
      tuple_sp_drain_race_dest: [{:bonus, {:sp_drain_race, :undead}, 4}],
      tuple_exp_add_class_dest: [{:bonus, {:exp_add_class, :all}, 10}],
      flat_crit_rate: [{:bonus, :crit_rate, 5}],
      flat_sp_drain_value: [{:bonus, :sp_drain_value, 3}],
      flat_no_size_fix: [{:bonus, :no_size_fix, 1}],
      flat_intravision: [{:bonus, :intravision, 1}],
      tuple_def_ratio_atk_class_dest: [{:bonus, {:def_ratio_atk_class, :boss}, 1}],
      tuple_sub_skill_dest: [{:bonus, {:sub_skill, 152}, 20}],
      tuple_sub_def_ele_dest: [{:bonus, {:sub_def_ele, :fire}, 10}],
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
      ],
      grant_skill: [{:grant_skill, 28, 3}],
      grant_skill_refine_level: [{:grant_skill, 28, {:+, 1, :refine}}],
      skill_lv_expr: [{:bonus, :heal_power, {:skill_lv, 87}}],
      skill_lv_condition: [{:if, {:>, {:skill_lv, 87}, 0}, [{:bonus, :int, 3}], []}],
      stat_expr: [{:bonus, :atk, {:div, {:stat, :str}, 10}}],
      stat_condition: [{:if, {:>=, {:stat, :int}, 120}, [{:bonus, :matk, 10}], []}],
      stat_combined: [{:bonus, :hit, {:div, {:+, {:stat, :str}, {:stat, :dex}}, 12}}],
      min_expr: [{:bonus, :atk, {:div, {:min, :base_level, 195}, 15}}],
      max_expr: [{:bonus, :atk, {:max, 1, :refine}}],
      pow_nested: [{:bonus, :atk, {:pow, {:min, :refine, 15}, 2}}],
      pow_scaled: [{:bonus, :atk, {:div, {:*, {:pow, :refine, 2}, 125}, 100}}],
      job_cmp_eq: [{:if, {:job_cmp, :==, :base_class, :swordman}, [{:bonus, :str, 1}], []}],
      job_cmp_ne: [{:if, {:job_cmp, :!=, :class, :soul_linker}, [{:bonus, :int, 1}], []}],
      job_cmp_or: [
        {:if, {:or, {:job_cmp, :==, :base_class, :mage}, {:job_cmp, :==, :base_class, :archer}},
         [{:bonus, :max_hp, {:*, :base_level, 5}}], []}
      ],
      bool_as_int: [{:bonus, :def, {:+, 2, {:*, 3, {:bool, {:>, :refine, 5}}}}}]
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

  describe "status effect instructions" do
    test "round-trips finite, infinite, and end effects" do
      program = [
        {:status_start, :sc_stun, {:*, :refine, 1_000}, 3},
        {:status_start, :sc_summer, :infinite, 1},
        {:status_end, :sc_summer}
      ]

      assert program |> EquipScript.to_source() |> EquipScript.parse!() == program
    end

    test "rejects malformed status shapes and reserves :infinite for duration" do
      assert_raise ArgumentError, fn ->
        EquipScript.parse!("status_start(ctx, 10, 1_000, 1)")
      end

      assert_raise ArgumentError, fn ->
        EquipScript.parse!("status_start(ctx, :sc_stun, 1_000, :infinite)")
      end

      assert_raise ArgumentError, fn ->
        EquipScript.parse!("status_end(ctx, :sc_stun, 1)")
      end
    end

    test "omits finite status starts with non-positive evaluated durations" do
      program = [
        {:status_start, :sc_stun, 0, 1},
        {:status_start, :sc_freeze, {:-, :refine, 10}, 1}
      ]

      assert EquipScript.evaluate(program, on(5)).effects == []
    end

    test "evaluates effects in source order without changing modifier folding" do
      program = [
        {:status_start, :sc_stun, {:*, :refine, 1_000}, 3},
        {:bonus, :str, 2},
        {:status_end, :sc_stun},
        {:status_start, :sc_summer, :infinite, {:+, :job_level, 1}},
        {:bonus, :str, 4}
      ]

      assert EquipScript.evaluate(program, on(2, job_level: 5)) ==
               %EquipScript.Result{
                 modifiers: %{str: 6},
                 autobonuses: [],
                 effects: [
                   {:status_start, :sc_stun, 2_000, 3},
                   {:status_end, :sc_stun},
                   {:status_start, :sc_summer, :infinite, 6}
                 ]
               }
    end
  end

  describe "autobonus instructions" do
    test "round-trips attack, when-hit, and on-skill registrations" do
      primary = [
        {:bonus, :atk, {:div, :base_level, 10}},
        {:bonus, {:skill_varcast_rate, 271}, -100}
      ]

      secondary = [{:status_start, :sc_stun, 1_000, 1}]

      program = [
        {:autobonus, %{trigger: :attack, battle_flag: 17, primary: primary, secondary: secondary},
         {:*, :refine, 100}, 5_000},
        {:autobonus, %{trigger: :when_hit, battle_flag: 34, primary: primary, secondary: []}, 250,
         {:*, :job_level, 100}},
        {:autobonus,
         %{trigger: {:on_skill, 28}, battle_flag: 0, primary: primary, secondary: secondary},
         1_000, 3_000}
      ]

      assert program |> EquipScript.to_source() |> EquipScript.parse!() == program
    end

    test "rejects malformed and unknown registration data" do
      valid = "%{trigger: :attack, battle_flag: 17, primary: [], secondary: []}"

      invalid_specs = [
        "%{trigger: :bogus, battle_flag: 17, primary: [], secondary: []}",
        "%{trigger: {:on_skill, 0}, battle_flag: 0, primary: [], secondary: []}",
        "%{trigger: :attack, battle_flag: -1, primary: [], secondary: []}",
        "%{trigger: :attack, battle_flag: 17, primary: []}",
        "%{trigger: :attack, battle_flag: 17, primary: [], secondary: [], extra: 1}",
        "%{trigger: :attack, battle_flag: 17, primary: [heal(ctx, 1)], secondary: []}",
        "%{trigger: :attack, battle_flag: 17, primary: :not_a_program, secondary: []}"
      ]

      for spec <- invalid_specs do
        assert_raise ArgumentError, fn ->
          EquipScript.parse!("autobonus(ctx, #{spec}, 100, 1_000)")
        end
      end

      assert_raise ArgumentError, fn ->
        EquipScript.parse!("autobonus(ctx, #{valid}, 100, :infinite)")
      end

      assert_raise ArgumentError, fn ->
        EquipScript.evaluate(
          [
            {:autobonus, %{trigger: :attack, battle_flag: 17, primary: [], secondary: []}, 100,
             :infinite}
          ],
          on(0)
        )
      end
    end

    test "omits registrations with zero or negative evaluated rate or duration" do
      spec = %{trigger: :attack, battle_flag: 17, primary: [], secondary: []}

      program = [
        {:autobonus, spec, 0, 1_000},
        {:autobonus, spec, -1, 1_000},
        {:autobonus, spec, 1_000, 0},
        {:autobonus, spec, 1_000, {:-, :refine, 10}}
      ]

      assert EquipScript.evaluate(program, on(5)).autobonuses == []
    end

    test "evaluates registrations against pure inputs in their own source order" do
      first = %{trigger: :attack, battle_flag: 17, primary: [{:bonus, :atk, 5}], secondary: []}

      second = %{
        trigger: {:on_skill, 28},
        battle_flag: 0,
        primary: [{:bonus, :str, 2}],
        secondary: [{:status_end, :sc_stun}]
      }

      program = [
        {:autobonus, first, {:*, :refine, 100}, {:*, :base_level, 10}},
        {:status_end, :sc_stun},
        {:bonus, :vit, 3},
        {:autobonus, second, {:*, :job_level, 10}, 2_000}
      ]

      assert EquipScript.evaluate(program, on(4, base_level: 20, job_level: 7)) ==
               %EquipScript.Result{
                 modifiers: %{vit: 3},
                 effects: [{:status_end, :sc_stun}],
                 autobonuses: [
                   Map.merge(first, %{rate: 400, duration_ms: 200}),
                   Map.merge(second, %{rate: 70, duration_ms: 2_000})
                 ]
               }
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

    test "parses a valid stat expression and rejects an unknown stat atom" do
      assert [{:bonus, :atk, {:stat, :str}}] =
               EquipScript.parse!("bonus(ctx, :atk, stat(ctx, :str))")

      assert_raise ArgumentError, fn ->
        EquipScript.parse!("bonus(ctx, :atk, stat(ctx, :max_hp))")
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

  describe "evaluate/2" do
    test "returns modifiers in a structured result" do
      result = EquipScript.evaluate([{:bonus, :str, 2}], on(0))

      assert result == %EquipScript.Result{modifiers: %{str: 2}, autobonuses: [], effects: []}
    end
  end

  describe "eval/2" do
    test "returns only modifiers when the program also emits effects and registrations" do
      spec = %{trigger: :when_hit, battle_flag: 34, primary: [], secondary: []}

      program = [
        {:status_start, :sc_stun, 1_000, 1},
        {:bonus, :str, 2},
        {:autobonus, spec, 100, 5_000}
      ]

      assert EquipScript.eval(program, on(0)) == %{str: 2}
    end

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

    test "perfect-hit rate keeps the largest value while additive rate sums" do
      program = [
        {:bonus, :perfect_hit_rate, 25},
        {:bonus, :perfect_hit_rate, 10},
        {:bonus, :perfect_hit, 5},
        {:bonus, :perfect_hit, 3}
      ]

      assert EquipScript.eval(program, on(0)) == %{perfect_hit_rate: 25, perfect_hit: 8}
    end

    test "defender proc siblings use last-writer semantics" do
      key = {:def_set_race_rate, :player_human}
      program = [{:bonus, key, 10_000}, {:bonus, key, 5_000}]

      assert EquipScript.eval(program, on(0)) == %{key => 5_000}
      assert EquipScript.eval(Enum.reverse(program), on(0)) == %{key => 10_000}
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

    test "evaluates soft-DEF rate and sums race-specific SP drain values" do
      key = {:sp_drain_race, :undead}
      program = [{:bonus, :def2_rate, 25}, {:bonus, key, 3}, {:bonus, key, 4}]

      assert EquipScript.eval(program, on(0)) == %{key => 7, def2_rate: 25}
    end

    test "evaluates monster defense and item-group drop bonuses" do
      def_key = {:add_def_monster, 1917}
      drop_key = {:add_monster_drop_group, :food}
      program = [{:bonus, def_key, 10}, {:bonus, drop_key, 10_000}]

      assert EquipScript.eval(program, on(0)) == %{def_key => 10, drop_key => 10_000}
    end

    test "evaluates the new flat and parameterized bonuses" do
      program = [
        {:bonus, :hit_rate, 15},
        {:bonus, :movement_speed_add, 20},
        {:bonus, :critical_long, 7},
        {:bonus, {:coma_class, :boss}, 250},
        {:bonus, {:add_item_group_heal, :food}, 30}
      ]

      assert EquipScript.eval(program, on(0)) == %{
               {:coma_class, :boss} => 250,
               {:add_item_group_heal, :food} => 30,
               hit_rate: 15,
               movement_speed_add: 20,
               critical_long: 7
             }
    end

    test "combines no-regen contributions as a bitmask" do
      program = [{:bonus, :no_regen, 1}, {:bonus, :no_regen, 2}]

      assert EquipScript.eval(program, on(0)) == %{no_regen: 3}
    end

    test "keeps the amount paired with the highest get-zeny chance" do
      program = [
        {:paired_choice, :get_zeny, 500, 10},
        {:paired_choice, :get_zeny, 100, 25},
        {:paired_choice, :get_zeny, 900, 20}
      ]

      assert EquipScript.eval(program, on(0)) == %{get_zeny: {25, 100}}
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

    test "grant_skill folds into a reserved granted-skill key" do
      assert EquipScript.eval([{:grant_skill, 28, 3}], on(0)) == %{{:granted_skill, 28} => 3}
    end

    test "grant_skill evaluates a refine-dependent level and keeps the strongest" do
      program = [{:grant_skill, 28, {:+, 1, :refine}}, {:grant_skill, 28, 2}]

      assert EquipScript.eval(program, on(5)) == %{{:granted_skill, 28} => 6}
      assert EquipScript.eval(program, on(0)) == %{{:granted_skill, 28} => 2}
    end

    test "skill_lv reads the wearer's learned level from the inputs" do
      program = [{:bonus, :heal_power, {:skill_lv, 87}}]

      assert EquipScript.eval(program, on(0, learned_skills: %{87 => 4})) == %{heal_power: 4}
    end

    test "skill_lv defaults to 0 when the learned-skills input is absent" do
      program = [{:if, {:>, {:skill_lv, 87}, 0}, [{:bonus, :int, 3}], []}]

      assert EquipScript.eval(program, on(0)) == %{}
      assert EquipScript.eval(program, on(0, learned_skills: %{87 => 1})) == %{int: 3}
    end

    test "stat reads the wearer's stat from the inputs" do
      program = [{:bonus, :atk, {:div, {:stat, :str}, 10}}]

      assert EquipScript.eval(program, on(0, stats: %{str: 95})) == %{atk: 9}
    end

    test "a stat gate picks its branch from the stat value" do
      program = [{:if, {:>=, {:stat, :int}, 120}, [{:bonus, :matk, 10}], []}]

      assert EquipScript.eval(program, on(0, stats: %{int: 120})) == %{matk: 10}
      assert EquipScript.eval(program, on(0, stats: %{int: 119})) == %{}
    end

    test "a stat defaults to 0 when the stats input is absent" do
      program = [{:if, {:>=, {:stat, :str}, 1}, [{:bonus, :atk, 5}], []}]

      assert EquipScript.eval(program, on(0)) == %{}
      assert EquipScript.eval(program, on(0, stats: %{str: 1})) == %{atk: 5}
    end

    test "min and max clamp their operands" do
      assert EquipScript.eval([{:bonus, :atk, {:min, :base_level, 195}}], on(0, base_level: 250)) ==
               %{atk: 195}

      assert EquipScript.eval([{:bonus, :atk, {:max, 1, :refine}}], on(0)) == %{atk: 1}
      assert EquipScript.eval([{:bonus, :atk, {:max, 1, :refine}}], on(9)) == %{atk: 9}
    end

    test "pow raises the base to a non-negative integer exponent" do
      assert EquipScript.eval([{:bonus, :atk, {:pow, :refine, 2}}], on(12)) == %{atk: 144}

      assert EquipScript.eval([{:bonus, :atk, {:pow, {:min, :refine, 15}, 2}}], on(20)) ==
               %{atk: 225}
    end

    test "pow with a negative exponent truncates to zero" do
      assert EquipScript.eval([{:bonus, :atk, {:pow, 2, {:-, 0, :refine}}}], on(3)) == %{atk: 0}
    end

    test "a job_cmp gate matches on the current job and its lineage" do
      # 7 = Knight, whose base_class is Swordman.
      program = [{:if, {:job_cmp, :==, :base_class, :swordman}, [{:bonus, :str, 1}], []}]

      assert EquipScript.eval(program, on(0, job_id: 7)) == %{str: 1}
      assert EquipScript.eval(program, on(0, job_id: 9)) == %{}
    end

    test "a job_cmp inequality matches every job but the excluded one" do
      program = [{:if, {:job_cmp, :!=, :class, :wizard}, [{:bonus, :int, 1}], []}]

      assert EquipScript.eval(program, on(0, job_id: 7)) == %{int: 1}
      assert EquipScript.eval(program, on(0, job_id: 9)) == %{}
    end

    test "an absent job_id input reads as Novice" do
      program = [{:if, {:job_cmp, :==, :base_class, :novice}, [{:bonus, :str, 1}], []}]

      assert EquipScript.eval(program, on(0)) == %{str: 1}
    end

    test "a bool-as-int expression yields 1 or 0" do
      program = [{:bonus, :def, {:+, 2, {:*, 3, {:bool, {:>, :refine, 5}}}}}]

      assert EquipScript.eval(program, on(9)) == %{def: 5}
      assert EquipScript.eval(program, on(3)) == %{def: 2}
    end
  end
end
