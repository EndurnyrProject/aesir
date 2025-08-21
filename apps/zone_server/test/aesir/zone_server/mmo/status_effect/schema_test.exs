defmodule Aesir.ZoneServer.Mmo.StatusEffect.SchemaTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Schema

  @valid_effect %{
    properties: [:buff, :cannot_dispel],
    calc_flags: [:stat_atk],
    modifiers: %{
      atk: 10,
      matk: 5
    },
    flags: [:no_save],
    on_apply: %{
      type: :notify_client,
      packet: :status_start,
      data: %{icon: 1}
    },
    on_remove: [
      %{type: :heal, formula: "max_hp * 0.1"},
      %{type: :remove_status, status: :sc_curse}
    ],
    tick: %{
      interval: 1000,
      actions: %{
        type: :damage,
        formula: "10 + skill_level * 5"
      }
    }
  }

  describe "validate/1 - always strict" do
    test "validates a simple valid status effect" do
      effect = %{
        properties: [:buff],
        modifiers: %{atk: 10}
      }

      result = Schema.validate(effect)
      assert %{properties: [:buff]} = result
    end

    test "validates complex nested structures" do
      result = Schema.validate(@valid_effect)
      assert %{properties: [:buff, :cannot_dispel]} = result
    end

    test "raises on unknown fields" do
      effect = Map.put(@valid_effect, :unknown_field, "value")

      assert_raise RuntimeError, ~r/validation failed/, fn ->
        Schema.validate(effect)
      end
    end

    test "raises on completely invalid effects" do
      invalid_effect = %{invalid: true}

      assert_raise RuntimeError, ~r/validation failed/, fn ->
        Schema.validate(invalid_effect)
      end
    end

    test "raises on invalid action type" do
      effect = %{
        on_apply: %{
          type: :invalid_action_type,
          data: "test"
        }
      }

      assert_raise RuntimeError, ~r/validation failed/, fn ->
        Schema.validate(effect)
      end
    end

    test "validates action lists with atoms" do
      effect = %{
        properties: [:buff],
        on_apply: :remove,
        on_remove: [:heal_full, :notify_end]
      }

      result = Schema.validate(effect)
      assert %{on_apply: :remove} = result
    end

    test "validates tick configuration" do
      effect = %{
        tick: %{
          interval: 5000,
          actions: [
            %{type: :damage, formula: "100"},
            %{type: :heal, formula: "50"}
          ]
        }
      }

      result = Schema.validate(effect)
      assert %{tick: %{interval: 5000}} = result
    end

    test "validates conditional actions" do
      effect = %{
        on_damage: %{
          type: :conditional,
          condition: "damage > 100",
          then_actions: %{type: :remove_status, status: :sc_blessing},
          else_actions: %{type: :heal, formula: "50"}
        }
      }

      result = Schema.validate(effect)
      assert %{on_damage: %{type: :conditional}} = result
    end

    test "validates multi-phase status effects" do
      effect = %{
        properties: [:debuff],
        phases: %{
          phase1: %{
            duration: 5000,
            modifiers: %{str: -10},
            next: :phase2
          },
          phase2: %{
            duration: 3000,
            modifiers: %{str: -20, agi: -10}
          }
        }
      }

      result = Schema.validate(effect)
      assert %{phases: %{phase1: _, phase2: _}} = result
    end
  end

  describe "validate!/1 - alias for validate" do
    test "returns validated effect when valid" do
      result = Schema.validate!(@valid_effect)
      assert %{properties: [:buff, :cannot_dispel]} = result
    end

    test "raises when invalid" do
      assert_raise RuntimeError, ~r/validation failed/, fn ->
        Schema.validate!(%{invalid: true})
      end
    end
  end

  describe "validate_all/1 - validates map of effects" do
    test "validates all effects in a map" do
      effects = %{
        sc_blessing: %{
          properties: [:buff],
          modifiers: %{str: 10}
        },
        sc_curse: %{
          properties: [:debuff],
          modifiers: %{luk: -10}
        }
      }

      result = Schema.validate_all(effects)
      assert %{sc_blessing: _, sc_curse: _} = result
    end

    test "raises on first invalid effect with ID in error" do
      effects = %{
        sc_valid: %{
          properties: [:buff]
        },
        sc_invalid: %{
          invalid_field: true
        }
      }

      assert_raise RuntimeError, ~r/sc_invalid/, fn ->
        Schema.validate_all(effects)
      end
    end
  end

  describe "conforms?/1" do
    test "returns true for valid effects" do
      assert Schema.conforms?(@valid_effect)
    end

    test "returns false for invalid effects" do
      refute Schema.conforms?(%{invalid: true})
    end

    test "returns false for effects with unknown fields" do
      effect = Map.put(@valid_effect, :unknown, "value")
      refute Schema.conforms?(effect)
    end
  end

  describe "action_types/0" do
    test "returns list of all valid action types" do
      types = Schema.action_types()

      assert :damage in types
      assert :heal in types
      assert :modify_stat in types
      assert :apply_status in types
      assert :conditional in types
      assert length(types) == 18
    end
  end

  describe "validate_formula/1" do
    test "accepts valid formula strings" do
      assert :ok = Schema.validate_formula("base_level * 10")
      assert :ok = Schema.validate_formula("skill_level + 5")
      assert :ok = Schema.validate_formula("100")
    end

    test "rejects empty formulas" do
      assert {:error, _, _} = Schema.validate_formula("")
    end

    test "rejects non-string formulas" do
      assert {:error, _, _} = Schema.validate_formula(123)
      assert {:error, _, _} = Schema.validate_formula(nil)
    end
  end

  describe "edge cases" do
    test "handles empty effect definition" do
      assert_raise RuntimeError, fn ->
        Schema.validate(%{})
      end
    end

    test "handles nil values in optional fields" do
      effect = %{
        properties: [:buff],
        modifiers: nil,
        flags: nil
      }

      # Should pass since these fields are optional
      result = Schema.validate(effect)
      assert %{properties: [:buff]} = result
    end

    test "validates deeply nested action lists" do
      effect = %{
        on_apply: [
          %{type: :heal, formula: "100"},
          [
            %{type: :damage, formula: "50"},
            :some_reference
          ]
        ]
      }

      # Nested lists within lists should work
      result = Schema.validate(effect)
      assert %{on_apply: _} = result
    end
  end
end
