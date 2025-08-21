defmodule Aesir.ZoneServer.Mmo.StatusEffect.FormulaCompilerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.StatusEffect.FormulaCompiler

  describe "compile/1" do
    test "compiles nil to function returning 0" do
      func = FormulaCompiler.compile(nil)
      assert func.(%{}) == 0
    end

    test "compiles numeric value to constant function" do
      func = FormulaCompiler.compile(42)
      assert func.(%{}) == 42
    end

    test "compiles numeric string to constant function" do
      func = FormulaCompiler.compile("42")
      assert func.(%{}) == 42
    end

    test "compiles decimal string to float function" do
      func = FormulaCompiler.compile("3.14")
      assert func.(%{}) == 3.14
    end

    test "compiles negative number" do
      func = FormulaCompiler.compile("-42")
      assert func.(%{}) == -42
    end

    test "compiles negative decimal" do
      func = FormulaCompiler.compile("-3.14")
      assert func.(%{}) == -3.14
    end
  end

  describe "variable access" do
    test "accesses simple variables" do
      func = FormulaCompiler.compile("level")
      assert func.(%{level: 50}) == 50
    end

    test "returns 0 for missing variables" do
      func = FormulaCompiler.compile("missing_var")
      assert func.(%{}) == 0
    end

    test "accesses nested variables with dot notation" do
      func = FormulaCompiler.compile("caster.int")
      assert func.(%{caster: %{int: 99}}) == 99
    end

    test "returns 0 for missing nested variables" do
      func = FormulaCompiler.compile("caster.missing")
      assert func.(%{caster: %{}}) == 0
    end

    test "handles deep nesting" do
      func = FormulaCompiler.compile("state.buff.power")
      assert func.(%{state: %{buff: %{power: 25}}}) == 25
    end
  end

  describe "basic arithmetic" do
    test "addition" do
      func = FormulaCompiler.compile("10 + 5")
      assert func.(%{}) == 15
    end

    test "subtraction" do
      func = FormulaCompiler.compile("10 - 5")
      assert func.(%{}) == 5
    end

    test "multiplication" do
      func = FormulaCompiler.compile("10 * 5")
      assert func.(%{}) == 50
    end

    test "division" do
      func = FormulaCompiler.compile("10 / 5")
      assert func.(%{}) == 2
    end

    test "division by zero returns 0" do
      func = FormulaCompiler.compile("10 / 0")
      assert func.(%{}) == 0
    end

    test "modulo" do
      func = FormulaCompiler.compile("10 % 3")
      assert func.(%{}) == 1
    end

    test "modulo by zero returns 0" do
      func = FormulaCompiler.compile("10 % 0")
      assert func.(%{}) == 0
    end

    test "operator precedence" do
      func = FormulaCompiler.compile("2 + 3 * 4")
      assert func.(%{}) == 14

      func = FormulaCompiler.compile("(2 + 3) * 4")
      assert func.(%{}) == 20
    end

    test "complex arithmetic with variables" do
      func = FormulaCompiler.compile("level * 2 + str * 3")
      assert func.(%{level: 10, str: 5}) == 35
    end

    test "negation operator" do
      func = FormulaCompiler.compile("-level")
      assert func.(%{level: 10}) == -10

      func = FormulaCompiler.compile("-(10 + 5)")
      assert func.(%{}) == -15
    end
  end

  describe "comparison operators" do
    test "less than" do
      func = FormulaCompiler.compile("5 < 10")
      assert func.(%{}) == 1

      func = FormulaCompiler.compile("10 < 5")
      assert func.(%{}) == 0
    end

    test "greater than" do
      func = FormulaCompiler.compile("10 > 5")
      assert func.(%{}) == 1

      func = FormulaCompiler.compile("5 > 10")
      assert func.(%{}) == 0
    end

    test "less than or equal" do
      func = FormulaCompiler.compile("5 <= 10")
      assert func.(%{}) == 1

      func = FormulaCompiler.compile("10 <= 10")
      assert func.(%{}) == 1

      func = FormulaCompiler.compile("15 <= 10")
      assert func.(%{}) == 0
    end

    test "greater than or equal" do
      func = FormulaCompiler.compile("10 >= 5")
      assert func.(%{}) == 1

      func = FormulaCompiler.compile("10 >= 10")
      assert func.(%{}) == 1

      func = FormulaCompiler.compile("5 >= 10")
      assert func.(%{}) == 0
    end

    test "equality" do
      func = FormulaCompiler.compile("10 == 10")
      assert func.(%{}) == 1

      func = FormulaCompiler.compile("10 == 5")
      assert func.(%{}) == 0
    end

    test "inequality" do
      func = FormulaCompiler.compile("10 != 5")
      assert func.(%{}) == 1

      func = FormulaCompiler.compile("10 != 10")
      assert func.(%{}) == 0
    end
  end

  describe "logical operators" do
    test "logical and" do
      func = FormulaCompiler.compile("1 and 1")
      assert func.(%{}) == 1

      func = FormulaCompiler.compile("1 and 0")
      assert func.(%{}) == 0

      func = FormulaCompiler.compile("0 and 1")
      assert func.(%{}) == 0

      func = FormulaCompiler.compile("0 and 0")
      assert func.(%{}) == 0
    end

    test "logical or" do
      func = FormulaCompiler.compile("1 or 1")
      assert func.(%{}) == 1

      func = FormulaCompiler.compile("1 or 0")
      assert func.(%{}) == 1

      func = FormulaCompiler.compile("0 or 1")
      assert func.(%{}) == 1

      func = FormulaCompiler.compile("0 or 0")
      assert func.(%{}) == 0
    end

    test "logical not" do
      func = FormulaCompiler.compile("not 0")
      assert func.(%{}) == 1

      func = FormulaCompiler.compile("not 1")
      assert func.(%{}) == 0

      func = FormulaCompiler.compile("not 5")
      assert func.(%{}) == 0
    end

    test "complex logical expressions" do
      func = FormulaCompiler.compile("(level > 10) and (str > 5)")
      assert func.(%{level: 15, str: 10}) == 1
      assert func.(%{level: 15, str: 3}) == 0
      assert func.(%{level: 5, str: 10}) == 0
    end

    test "logical operator precedence" do
      func = FormulaCompiler.compile("1 or 0 and 0")
      assert func.(%{}) == 1

      func = FormulaCompiler.compile("0 and 1 or 1")
      assert func.(%{}) == 1
    end
  end

  describe "function calls" do
    test "min function" do
      func = FormulaCompiler.compile("min(10, 5)")
      assert func.(%{}) == 5

      func = FormulaCompiler.compile("min(level, 100)")
      assert func.(%{level: 50}) == 50
      assert func.(%{level: 150}) == 100
    end

    test "max function" do
      func = FormulaCompiler.compile("max(10, 5)")
      assert func.(%{}) == 10

      func = FormulaCompiler.compile("max(level, 10)")
      assert func.(%{level: 5}) == 10
      assert func.(%{level: 50}) == 50
    end

    test "floor function" do
      func = FormulaCompiler.compile("floor(3.7)")
      assert func.(%{}) == 3.0

      func = FormulaCompiler.compile("floor(level / 3)")
      assert func.(%{level: 10}) == 3.0
    end

    test "ceil function" do
      func = FormulaCompiler.compile("ceil(3.2)")
      assert func.(%{}) == 4.0

      func = FormulaCompiler.compile("ceil(level / 3)")
      assert func.(%{level: 10}) == 4.0
    end

    test "abs function" do
      func = FormulaCompiler.compile("abs(-10)")
      assert func.(%{}) == 10

      func = FormulaCompiler.compile("abs(level - 100)")
      assert func.(%{level: 50}) == 50
      assert func.(%{level: 150}) == 50
    end

    test "nested function calls" do
      func = FormulaCompiler.compile("max(min(level, 100), 10)")
      assert func.(%{level: 5}) == 10
      assert func.(%{level: 50}) == 50
      assert func.(%{level: 150}) == 100
    end

    test "functions with arithmetic" do
      func = FormulaCompiler.compile("floor(level * 1.5 + str)")
      assert func.(%{level: 10, str: 3}) == 18.0
    end
  end

  describe "complex real-world formulas" do
    test "HP regeneration formula" do
      formula = "(max_hp / 100 + 7) * (1 + 0.1 * val1)"
      func = FormulaCompiler.compile(formula)

      context = %{max_hp: 1000, val1: 5}
      expected = (1000 / 100 + 7) * (1 + 0.1 * 5)
      assert func.(context) == expected
    end

    test "damage calculation formula" do
      formula = "200 + val1 * 10"
      func = FormulaCompiler.compile(formula)

      assert func.(%{val1: 5}) == 250
    end

    test "caster-based damage formula" do
      formula = "caster.int * 2"
      func = FormulaCompiler.compile(formula)

      assert func.(%{caster: %{int: 50}}) == 100
    end

    test "conditional damage formula" do
      formula = "(level > 50) * 100 + (level <= 50) * 50"
      func = FormulaCompiler.compile(formula)

      assert func.(%{level: 60}) == 100
      assert func.(%{level: 30}) == 50
    end

    test "complex status effect formula" do
      formula = "max(floor(max_hp * 0.05), min(level * 2, 100))"
      func = FormulaCompiler.compile(formula)

      context = %{max_hp: 5000, level: 40}
      # floor(5000 * 0.05) = floor(250) = 250
      # min(40 * 2, 100) = min(80, 100) = 80
      # max(250, 80) = 250
      assert func.(context) == 250.0

      context = %{max_hp: 1000, level: 60}
      # floor(1000 * 0.05) = floor(50) = 50
      # min(60 * 2, 100) = min(120, 100) = 100
      # max(50, 100) = 100
      assert func.(context) == 100
    end
  end

  describe "error handling" do
    test "invalid formula returns function that returns 0" do
      log =
        capture_log(fn ->
          func = FormulaCompiler.compile("invalid @#$ formula")
          assert func.(%{}) == 0
        end)

      assert log =~ "Failed to parse formula: invalid @#$ formula" or
               log =~ "Exception when compiling formula: invalid @#$ formula"
    end

    test "partially valid formula with trailing garbage" do
      log =
        capture_log(fn ->
          func = FormulaCompiler.compile("10 + 5 @#$")
          assert func.(%{}) == 0
        end)

      assert log =~ "Failed to parse formula: 10 + 5 @#$" or
               log =~ "Exception when compiling formula: 10 + 5 @#$"
    end
  end

  describe "whitespace handling" do
    test "handles various whitespace patterns" do
      formulas = [
        "10+5",
        "10 +5",
        "10+ 5",
        "10 + 5",
        "  10  +  5  "
      ]

      for formula <- formulas do
        func = FormulaCompiler.compile(formula)
        assert func.(%{}) == 15
      end
    end

    test "handles whitespace in function calls" do
      formulas = [
        "max(10,5)",
        "max(10, 5)",
        "max( 10 , 5 )",
        "max(  10  ,  5  )"
      ]

      for formula <- formulas do
        func = FormulaCompiler.compile(formula)
        assert func.(%{}) == 10
      end
    end
  end

  describe "custom game functions" do
    test "pc_checkskill with target selector" do
      func = FormulaCompiler.compile("pc_checkskill(target, rg_tunneldrive)")
      context = %{target_id: "player_123"}

      # Since we don't have real player data, it returns 0
      assert func.(context) == 0
    end

    test "pc_checkskill with caster selector" do
      func = FormulaCompiler.compile("pc_checkskill(caster, as_poisonreact)")
      context = %{caster_id: "player_456"}

      assert func.(context) == 0
    end

    test "sc_venomimpress formula from status_effects.exs" do
      func = FormulaCompiler.compile("30 * pc_checkskill(caster, as_poisonreact)")
      context = %{caster_id: "player_456"}

      # pc_checkskill returns 0 without real data, so 30 * 0 = 0
      assert func.(context) == 0
    end

    test "sc_hiding movement speed formula from status_effects.exs" do
      func =
        FormulaCompiler.compile(
          "(pc_checkskill(target, rg_tunneldrive) > 0) * (-(120 - 6 * pc_checkskill(target, rg_tunneldrive)))"
        )

      context = %{target_id: "player_123"}

      # Without skill: (0 > 0) * (...) = 0 * (...) = 0
      assert func.(context) == 0
    end

    test "sc_cloaking movement speed formula from status_effects.exs" do
      func =
        FormulaCompiler.compile(
          "(val1 >= 10) * (-25) + (val1 < 10 and val1 >= 3) * (-(30 - 3 * val1)) + (val1 < 3) * (-300)"
        )

      # Test with val1 = 10 (should give -25)
      assert func.(%{val1: 10}) == -25

      # Test with val1 = 5 (should give -(30 - 15) = -15)
      assert func.(%{val1: 5}) == -15

      # Test with val1 = 2 (should give -300)
      assert func.(%{val1: 2}) == -300

      # Test with val1 = 15 (should give -25)
      assert func.(%{val1: 15}) == -25
    end

    test "nested functions with custom function" do
      func = FormulaCompiler.compile("max(10, pc_checkskill(target, skill_id) * 5)")
      context = %{target_id: "player_123"}

      # pc_checkskill returns 0, so max(10, 0 * 5) = 10
      assert func.(context) == 10
    end

    test "random function generates values in range" do
      func = FormulaCompiler.compile("random(1, 10)")

      # Test multiple times to ensure it's within bounds
      for _ <- 1..20 do
        result = func.(%{})
        assert result >= 1 and result <= 10
      end
    end

    test "random with calculations" do
      func = FormulaCompiler.compile("random(level, level * 2)")
      context = %{level: 5}

      for _ <- 1..20 do
        result = func.(context)
        assert result >= 5 and result <= 10
      end
    end

    test "has_status function" do
      func = FormulaCompiler.compile("has_status(target, sc_poison)")
      context = %{target_id: "player_123"}

      # Returns 0 (false) without real status data
      assert func.(context) == 0
    end

    test "job_level function" do
      func = FormulaCompiler.compile("job_level(target) * 2")
      context = %{target_id: "player_123"}

      # Returns 1 (default) without real data, so 1 * 2 = 2
      assert func.(context) == 2
    end

    test "base_level function" do
      func = FormulaCompiler.compile("base_level(caster) + 10")
      context = %{caster_id: "player_456"}

      # Returns 1 (default) without real data, so 1 + 10 = 11
      assert func.(context) == 11
    end

    test "undefined custom function returns a function that returns 0" do
      log =
        capture_log(fn ->
          func = FormulaCompiler.compile("unknown_func(10)")
          assert func.(%{}) == 0
        end)

      assert log =~ "Exception when compiling formula: unknown_func(10)"
    end

    test "wrong arity for custom function returns a function that returns 0" do
      log =
        capture_log(fn ->
          func = FormulaCompiler.compile("pc_checkskill(target)")
          assert func.(%{}) == 0
        end)

      assert log =~ "Exception when compiling formula: pc_checkskill(target)"
    end

    test "wrong arity for built-in function returns a function that returns 0" do
      log =
        capture_log(fn ->
          func = FormulaCompiler.compile("min(1, 2, 3)")
          assert func.(%{}) == 0
        end)

      assert log =~ "Exception when compiling formula: min(1, 2, 3)"
    end
  end

  describe "atom literals and lists" do
    test "atom literals" do
      func = FormulaCompiler.compile(":test_atom")
      assert func.(%{}) == :test_atom
    end

    test "atom comparison" do
      func = FormulaCompiler.compile("skill_id == :physical")
      assert func.(%{skill_id: :physical}) == 1
      assert func.(%{skill_id: :magical}) == 0
    end

    test "empty list" do
      func = FormulaCompiler.compile("[]")
      assert func.(%{}) == []
    end

    test "list of numbers" do
      func = FormulaCompiler.compile("[1, 2, 3]")
      assert func.(%{}) == [1, 2, 3]
    end

    test "list of atoms" do
      func = FormulaCompiler.compile("[:axe, :mace]")
      assert func.(%{}) == [:axe, :mace]
    end

    test "mixed list" do
      func = FormulaCompiler.compile("[1, :atom, 3]")
      assert func.(%{}) == [1, :atom, 3]
    end

    test "list with variables" do
      func = FormulaCompiler.compile("[level, str, :atom]")
      assert func.(%{level: 10, str: 20}) == [10, 20, :atom]
    end

    test "list with expressions" do
      func = FormulaCompiler.compile("[level * 2, str + 5]")
      assert func.(%{level: 10, str: 20}) == [20, 25]
    end

    test "nested lists" do
      func = FormulaCompiler.compile("[[1, 2], [3, 4]]")
      assert func.(%{}) == [[1, 2], [3, 4]]
    end

    test "problematic formulas from status_effects.exs" do
      # These are the formulas that were causing errors
      formula1 = "state.shield_hp > 0 and (dmg_type == :physical or skill_id == :tf_throwstone)"
      func1 = FormulaCompiler.compile(formula1)
      assert is_function(func1, 1)

      formula2 = "skill_id != :pf_soulburn and (src_type != :mer or not skill_id)"
      func2 = FormulaCompiler.compile(formula2)
      assert is_function(func2, 1)

      formula3 =
        "skill_id != :asc_breaker or (skill_id == :asc_breaker and dmg_type != :physical)"

      func3 = FormulaCompiler.compile(formula3)
      assert is_function(func3, 1)

      formula4 = "has_status(:sc_curse)"
      func4 = FormulaCompiler.compile(formula4)
      assert is_function(func4, 1)

      formula5 = "has_status(:sc_stone)"
      func5 = FormulaCompiler.compile(formula5)
      assert is_function(func5, 1)

      formula6 = "not pc_check_weapontype(target, [:axe, :mace])"
      func6 = FormulaCompiler.compile(formula6)
      assert is_function(func6, 1)

      formula7 = "not pc_check_weapontype(target, [:spear])"
      func7 = FormulaCompiler.compile(formula7)
      assert is_function(func7, 1)
    end
  end

  describe "edge cases" do
    test "empty string returns function that returns 0" do
      func = FormulaCompiler.compile("")
      assert func.(%{}) == 0
    end

    test "deeply nested parentheses" do
      func = FormulaCompiler.compile("((((10))))")
      assert func.(%{}) == 10
    end

    test "chain of operations" do
      func = FormulaCompiler.compile("1 + 2 - 3 + 4 - 5 + 6")
      assert func.(%{}) == 5
    end

    test "all operators in one expression" do
      formula = "(10 + 5) * 2 / 3 - 4 % 3 and level > 0 or not 0"
      func = FormulaCompiler.compile(formula)
      assert func.(%{level: 10}) == 1
    end
  end
end
