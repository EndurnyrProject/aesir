defmodule Aesir.ZoneServer.Mmo.Skill.DefinitionTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @required_opts [
    id: 1,
    name: :test_skill,
    display_name: "Test Skill",
    max_level: 5
  ]

  describe "resolve_mode/2" do
    test "leaves plain (non mode-keyed) option values unchanged" do
      opts = [sp_cost: [10], range: 5, display_name: "Test"]

      assert Definition.resolve_mode(opts, :renewal) == opts
      assert Definition.resolve_mode(opts, :pre_renewal) == opts
    end

    test "resolves a mode-keyed value on a mode-keyable field to the mode's entry" do
      opts = [sp_cost: [renewal: [10], pre_renewal: [12]]]

      assert Definition.resolve_mode(opts, :renewal) == [sp_cost: [10]]
      assert Definition.resolve_mode(opts, :pre_renewal) == [sp_cost: [12]]
    end

    test "resolves only the mode-keyed fields in a mixed option list" do
      opts = [
        sp_cost: [renewal: [10], pre_renewal: [12]],
        range: 5,
        display_name: "Test"
      ]

      assert Definition.resolve_mode(opts, :renewal) ==
               [sp_cost: [10], range: 5, display_name: "Test"]

      assert Definition.resolve_mode(opts, :pre_renewal) ==
               [sp_cost: [12], range: 5, display_name: "Test"]
    end
  end

  describe "requires" do
    test "accepts a declared requirement through use Skill" do
      [{module, _bytecode}] =
        Code.compile_string("""
        defmodule Aesir.ZoneServer.Mmo.Skill.DefinitionTest.InventorySkill do
          use Aesir.ZoneServer.Mmo.Skill,
            id: 9_001,
            name: :inventory_skill,
            display_name: "Inventory Skill",
            max_level: 1,
            requires: [:inventory]
        end
        """)

      assert module.definition().requires == [:inventory]
    end

    test "defaults to player-only requirements when not declared" do
      [{module, _bytecode}] =
        Code.compile_string("""
        defmodule Aesir.ZoneServer.Mmo.Skill.DefinitionTest.PermissiveSkill do
          use Aesir.ZoneServer.Mmo.Skill,
            id: 9_002,
            name: :permissive_skill,
            display_name: "Permissive Skill",
            max_level: 1
        end
        """)

      # An un-annotated skill defaults to player-only, so a mob never casts it.
      assert module.definition().requires == [:player_state]
      refute module.__requires_declared__()
    end

    test "rejects an unknown requirement and names it" do
      assert_raise ArgumentError, ~r/:inventroy/, fn ->
        Code.compile_string("""
        defmodule Aesir.ZoneServer.Mmo.Skill.DefinitionTest.InvalidRequirementSkill do
          use Aesir.ZoneServer.Mmo.Skill,
            id: 9_003,
            name: :invalid_requirement_skill,
            display_name: "Invalid Requirement Skill",
            max_level: 1,
            requires: [:inventroy]
        end
        """)
      end
    end
  end

  describe "mode-keyed use Skill options" do
    test "a mode-keyed option resolves per mode through definition/0 and definition/1" do
      [{module, _bytecode}] =
        Code.compile_string("""
        defmodule Aesir.ZoneServer.Mmo.Skill.DefinitionTest.ModeKeyedSkill do
          use Aesir.ZoneServer.Mmo.Skill,
            id: 9_004,
            name: :mode_keyed_skill,
            display_name: "Mode Keyed Skill",
            max_level: 1,
            sp_cost: [renewal: [10], pre_renewal: [12]]
        end
        """)

      assert module.definition().sp_cost == [10]
      assert module.definition(:renewal).sp_cost == [10]
      assert module.definition(:pre_renewal).sp_cost == [12]
    end

    test "a plain option resolves the same for both modes" do
      [{module, _bytecode}] =
        Code.compile_string("""
        defmodule Aesir.ZoneServer.Mmo.Skill.DefinitionTest.PlainCostSkill do
          use Aesir.ZoneServer.Mmo.Skill,
            id: 9_005,
            name: :plain_cost_skill,
            display_name: "Plain Cost Skill",
            max_level: 1,
            sp_cost: [10]
        end
        """)

      assert module.definition(:renewal).sp_cost == [10]
      assert module.definition(:pre_renewal).sp_cost == [10]
    end

    test "a mode-keyed value missing a mode key raises and names the module" do
      assert_raise ArgumentError, ~r/MissingModeKeySkill/, fn ->
        Code.compile_string("""
        defmodule Aesir.ZoneServer.Mmo.Skill.DefinitionTest.MissingModeKeySkill do
          use Aesir.ZoneServer.Mmo.Skill,
            id: 9_006,
            name: :missing_mode_key_skill,
            display_name: "Missing Mode Key Skill",
            max_level: 1,
            sp_cost: [renewal: [10]]
        end
        """)
      end
    end

    test "a mode-keyed value with an extra key raises and names the module" do
      assert_raise ArgumentError, ~r/ExtraModeKeySkill/, fn ->
        Code.compile_string("""
        defmodule Aesir.ZoneServer.Mmo.Skill.DefinitionTest.ExtraModeKeySkill do
          use Aesir.ZoneServer.Mmo.Skill,
            id: 9_007,
            name: :extra_mode_key_skill,
            display_name: "Extra Mode Key Skill",
            max_level: 1,
            sp_cost: [renewal: [10], pre_renewal: [12], other: 1]
        end
        """)
      end
    end

    test "a mode-keyed value on a non-mode-keyable field raises and names the module" do
      assert_raise ArgumentError, ~r/NonKeyableFieldSkill/, fn ->
        Code.compile_string("""
        defmodule Aesir.ZoneServer.Mmo.Skill.DefinitionTest.NonKeyableFieldSkill do
          use Aesir.ZoneServer.Mmo.Skill,
            id: 9_008,
            name: :non_keyable_field_skill,
            display_name: [renewal: "a", pre_renewal: "b"],
            max_level: 1
        end
        """)
      end
    end
  end

  describe "quest metadata" do
    test "defaults non-quest skills to no owner" do
      definition = Definition.build!(@required_opts, __MODULE__)

      refute definition.quest_skill
      assert is_nil(definition.quest_owner_job)
    end

    test "accepts a quest skill with a known owner job" do
      definition =
        Definition.build!(
          @required_opts ++ [quest_skill: true, quest_owner_job: :archer],
          __MODULE__
        )

      assert definition.quest_skill
      assert definition.quest_owner_job == :archer
    end

    test "rejects a quest skill without an owner job" do
      assert_raise ArgumentError, ~r/quest_owner_job/, fn ->
        Definition.build!(@required_opts ++ [quest_skill: true], __MODULE__)
      end
    end

    test "rejects a quest skill with an unknown owner job" do
      assert_raise ArgumentError, ~r/quest_owner_job/, fn ->
        Definition.build!(
          @required_opts ++ [quest_skill: true, quest_owner_job: :unknown_job],
          __MODULE__
        )
      end
    end
  end

  describe "target_type" do
    test "accepts :target_corpse" do
      defn = Definition.build!(@required_opts ++ [target_type: :target_corpse], __MODULE__)
      assert defn.target_type == :target_corpse
    end

    test "accepts :target_resurrection" do
      defn = Definition.build!(@required_opts ++ [target_type: :target_resurrection], __MODULE__)
      assert defn.target_type == :target_resurrection
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

  describe "resource costs" do
    test "defaults HP and sphere costs to empty lists" do
      defn = Definition.build!(@required_opts, __MODULE__)

      assert defn.hp_cost == []
      assert defn.sphere_cost == []
    end

    test "accepts fixed and all resource costs" do
      defn =
        Definition.build!(
          @required_opts ++ [hp_cost: [10], sp_cost: [:all], sphere_cost: [1, :all]],
          __MODULE__
        )

      assert defn.hp_cost == [10]
      assert defn.sp_cost == [:all]
      assert defn.sphere_cost == [1, :all]
    end

    test "rejects all HP costs" do
      assert_raise ArgumentError, ~r/DefinitionTest/, fn ->
        Definition.build!(@required_opts ++ [hp_cost: [:all]], __MODULE__)
      end
    end
  end

  describe "range" do
    test "defaults to 0 when omitted" do
      defn = Definition.build!(@required_opts, __MODULE__)
      assert defn.range == 0
    end

    test "accepts a flat integer" do
      defn = Definition.build!(@required_opts ++ [range: 9], __MODULE__)
      assert defn.range == 9
    end

    test "accepts the -1 weapon-range sentinel" do
      defn = Definition.build!(@required_opts ++ [range: -1], __MODULE__)
      assert defn.range == -1
    end

    test "accepts a per-level list" do
      defn = Definition.build!(@required_opts ++ [range: [3, 5, 7, 9, 11]], __MODULE__)
      assert defn.range == [3, 5, 7, 9, 11]
    end

    test "rejects a non-integer, non-list value" do
      assert_raise ArgumentError, ~r/DefinitionTest/, fn ->
        Definition.build!(@required_opts ++ [range: "far"], __MODULE__)
      end
    end
  end

  describe "range_at_level/2" do
    test "a flat range resolves the same regardless of level" do
      defn = Definition.build!(@required_opts ++ [range: 9], __MODULE__)

      assert Definition.range_at_level(defn, 1) == 9
      assert Definition.range_at_level(defn, 5) == 9
    end

    test "a flat -1 sentinel resolves unchanged" do
      defn = Definition.build!(@required_opts ++ [range: -1], __MODULE__)
      assert Definition.range_at_level(defn, 3) == -1
    end

    test "a per-level list resolves the entry at level - 1" do
      defn = Definition.build!(@required_opts ++ [range: [3, 5, 7, 9, 11]], __MODULE__)

      assert Definition.range_at_level(defn, 1) == 3
      assert Definition.range_at_level(defn, 3) == 7
      assert Definition.range_at_level(defn, 5) == 11
    end

    test "a per-level list at level 0 previews the first level instead of wrapping" do
      defn = Definition.build!(@required_opts ++ [range: [3, 5, 7, 9, 11]], __MODULE__)
      assert Definition.range_at_level(defn, 0) == 3
    end
  end
end
