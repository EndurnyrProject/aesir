defmodule Aesir.ZoneServer.Mmo.SkillTreeMageTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  {:ok, mage_id} = AvailableJobs.job_name_to_id(:mage)
  @mage_id mage_id

  {:ok, wizard_id} = AvailableJobs.job_name_to_id(:wizard)
  @wizard_id wizard_id

  @mage_skills [
    :mg_srecovery,
    :mg_sight,
    :mg_napalmbeat,
    :mg_soulstrike,
    :mg_safetywall,
    :mg_coldbolt,
    :mg_frostdiver,
    :mg_stonecurse,
    :mg_firebolt,
    :mg_fireball,
    :mg_firewall,
    :mg_lightningbolt,
    :mg_thunderstorm,
    :mg_energycoat
  ]

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp mage_progression(attrs) do
    Map.merge(
      %PlayerProgression{
        base_level: 99,
        job_level: 50,
        base_exp: 0,
        job_exp: 0,
        job_id: @mage_id,
        skill_point: 1,
        status_point: 0,
        learned_skills: %{}
      },
      Map.new(attrs)
    )
  end

  describe "tree_for/1 (real data)" do
    test "all 14 Mage skills resolve into the tree" do
      tree = SkillTree.tree_for(@mage_id)

      for name <- @mage_skills do
        assert Map.has_key?(tree, catalog_id(name)), "expected #{name} in Mage tree"
      end
    end

    test "no Mage skill is dropped as unimplemented when reloading the tree" do
      log = capture_log(fn -> SkillTree.reload() end)

      refute log =~ ~r/references unimplemented skill "MG_/
      refute log =~ "inherited job \"mage\" has no tree"
    end
  end

  describe "prerequisite gating" do
    test "Frost Diver needs Cold Bolt level 5" do
      frostdiver = catalog_id(:mg_frostdiver)
      coldbolt = catalog_id(:mg_coldbolt)

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(mage_progression(learned_skills: %{coldbolt => 4}), frostdiver)

      assert :ok =
               SkillTree.can_learn(mage_progression(learned_skills: %{coldbolt => 5}), frostdiver)
    end

    test "Safety Wall needs Napalm Beat level 7 and Soul Strike level 5" do
      safetywall = catalog_id(:mg_safetywall)
      napalm = catalog_id(:mg_napalmbeat)
      soulstrike = catalog_id(:mg_soulstrike)

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(
                 mage_progression(learned_skills: %{napalm => 7, soulstrike => 4}),
                 safetywall
               )

      assert :ok =
               SkillTree.can_learn(
                 mage_progression(learned_skills: %{napalm => 7, soulstrike => 5}),
                 safetywall
               )
    end

    test "Fire Wall needs Fire Ball level 5 and Sight level 1" do
      firewall = catalog_id(:mg_firewall)
      fireball = catalog_id(:mg_fireball)
      sight = catalog_id(:mg_sight)

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(mage_progression(learned_skills: %{fireball => 5}), firewall)

      assert :ok =
               SkillTree.can_learn(
                 mage_progression(learned_skills: %{fireball => 5, sight => 1}),
                 firewall
               )
    end
  end

  describe "wizard inheritance" do
    test "Wizard tree inherits the Mage skills" do
      tree = SkillTree.tree_for(@wizard_id)

      for name <- @mage_skills do
        assert Map.has_key?(tree, catalog_id(name)), "expected inherited #{name} in Wizard tree"
      end
    end
  end
end
