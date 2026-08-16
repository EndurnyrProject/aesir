defmodule Aesir.ZoneServer.Mmo.Skill.CatalogDiscoveryTest.StubSkill do
  @moduledoc """
  A skill defined in a test file. Discovery reads the `:zone_server` application
  manifest, which no test module is part of, so this must never reach the
  catalog - see the isolation test below.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 999_999,
    name: :stub_skill,
    display_name: "Stub Skill",
    max_level: 1,
    target_type: :self

  use Aesir.ZoneServer.Mmo.Skill.Performance

  @impl Aesir.ZoneServer.Mmo.Skill.Active
  def cast(_caster, _target, _level, _state), do: :ok
end

defmodule Aesir.ZoneServer.Mmo.Skill.CatalogDiscoveryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.CatalogDiscoveryTest.StubSkill
  alias Aesir.ZoneServer.TestSupport.EnsembleSkill

  @frozen_ids [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
    35,
    36,
    39,
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    48,
    49,
    50,
    51,
    52,
    53,
    80,
    81,
    83,
    84,
    85,
    86,
    87,
    88,
    89,
    90,
    91,
    92,
    93,
    116,
    122,
    142,
    143,
    144,
    145,
    146,
    147,
    148,
    149,
    150,
    151,
    152,
    153,
    154,
    155,
    156,
    157,
    1006
  ]

  test "every skill that existed when discovery replaced the hand-written list is still discovered" do
    ids = MapSet.new(Catalog.all(), & &1.id)
    missing = MapSet.difference(MapSet.new(@frozen_ids), ids)

    assert MapSet.subset?(MapSet.new(@frozen_ids), ids),
           "skill ids #{inspect(MapSet.to_list(missing))} vanished from the catalog - if a skill " <>
             "was removed on purpose, drop its id from @frozen_ids"
  end

  test "all/0 is sorted by skill id" do
    ids = Enum.map(Catalog.all(), & &1.id)

    assert ids == Enum.sort(ids)
  end

  test "no two skills claim the same id" do
    ids = Enum.map(Catalog.all(), & &1.id)

    assert ids == Enum.uniq(ids),
           "duplicate skill ids #{inspect(ids -- Enum.uniq(ids))} - by_id/1 keeps only one of each"
  end

  describe "test module isolation" do
    test "Performance alone supports an Active cast implementation and both capabilities" do
      assert Code.ensure_loaded?(StubSkill)
      assert :active in StubSkill.__skill_capabilities__()
      assert :performance in StubSkill.__skill_capabilities__()
    end

    test "a skill defined in a test file is not discovered" do
      assert Code.ensure_loaded?(StubSkill)
      assert :ok = Catalog.reload()

      refute 999_999 in Enum.map(Catalog.all(), & &1.id)
      assert :error = Catalog.by_name(:stub_skill)
      assert :error = Catalog.active_module_for(:stub_skill)
      assert :error = Catalog.performance_module_for(:stub_skill)
    end
  end

  describe "ensemble capability" do
    test "Ensemble implies Active without injecting a dynamic cost" do
      assert :active in EnsembleSkill.__skill_capabilities__()
      assert :ensemble in EnsembleSkill.__skill_capabilities__()
      refute function_exported?(EnsembleSkill, :dynamic_cost, 4)
    end

    test "catalog distinguishes ensembles and exposes both replayable capabilities" do
      assert Catalog.ensemble?(EnsembleSkill.definition().id)
      refute Catalog.ensemble?(319)

      assert Catalog.replayable?(EnsembleSkill.definition().id)
      assert Catalog.replayable?(319)
      refute Catalog.replayable?(1)
    end
  end

  describe "performance capability" do
    test "only shipped songs and dances are performances" do
      assert Catalog.performance_ids() ==
               MapSet.new([317, 319, 320, 321, 322, 325, 327, 328, 329, 330])
    end

    test "other Bard skills are not performances" do
      for name <- [
            :ba_frostjoker,
            :ba_pangvoice,
            :ba_musicalstrike,
            :ba_musicallesson,
            :bd_adaptation,
            :bd_encore
          ] do
        assert {:ok, definition} = Catalog.by_name(name)
        refute Catalog.performance?(definition.id)
      end
    end
  end

  describe "completeness" do
    @skills_dir Path.expand("../../../../../lib/aesir/zone_server/mmo/skills", __DIR__)

    @non_skill_modules [
      Aesir.ZoneServer.Mmo.Skill.Performance.Cost,
      Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot,
      Aesir.ZoneServer.Mmo.Skills.Blacksmith.ForgeSkill,
      Aesir.ZoneServer.Mmo.Skills.Monk.Combo,
      Aesir.ZoneServer.Mmo.Skills.Monk.Formulas,
      Aesir.ZoneServer.Mmo.Skills.Monk.Root,
      Aesir.ZoneServer.Mmo.Skills.Sage.ElementChange,
      Aesir.ZoneServer.Mmo.Skills.Sage.ElementField,
      Aesir.ZoneServer.Mmo.Skills.Wizard.EstimationView,
      Aesir.ZoneServer.Mmo.Skills.Guild.GuildArea,
      Aesir.ZoneServer.Mmo.Skills.Guild.Recall,
      Aesir.ZoneServer.Mmo.Skills.Hunter.Formulas,
      Aesir.ZoneServer.Mmo.Skills.Hunter.Trap,
      Aesir.ZoneServer.Mmo.Skills.Npc.SlaveSummon,
      Aesir.ZoneServer.Mmo.Skills.Npc.StatusStrike,
      Aesir.ZoneServer.Mmo.Skills.Shared.Envenom,
      Aesir.ZoneServer.Mmo.Skills.Rogue.PlagiarismCopyable,
      Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon
    ]

    test "every module under mmo/skills/ is either discovered or a declared helper" do
      modules = Enum.map(Path.wildcard(Path.join(@skills_dir, "**/*.ex")), &module_in_file/1)

      assert modules != [], "no modules found under #{@skills_dir}"

      for module <- modules, module not in @non_skill_modules do
        assert Code.ensure_loaded?(module) and function_exported?(module, :skill_name, 0),
               "#{inspect(module)} does not `use Skill` - declare it in @non_skill_modules"

        assert {:ok, definition} = Catalog.by_name(module.skill_name()),
               "#{inspect(module)} defines a skill but is not discovered by the Catalog"

        assert definition == module.definition()
      end
    end

    test "the declared helpers really are not skills" do
      for module <- @non_skill_modules do
        refute function_exported?(module, :__skill_capabilities__, 0),
               "#{inspect(module)} is a skill and must not be listed as a helper"
      end
    end

    defp module_in_file(path) do
      [_, name] = Regex.run(~r/^defmodule\s+([\w.]+)\s+do$/m, File.read!(path))

      Module.concat([name])
    end
  end
end
