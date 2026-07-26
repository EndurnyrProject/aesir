defmodule Aesir.ZoneServer.Mmo.Skill.QuestSkillMetadataTest do
  @moduledoc """
  Guards the permanent-ownership metadata every implemented `F_GetPlatinumSkills`
  reference must carry. Task 22 built the quest-skill lineage semantics
  (`Definition.quest_skill`/`quest_owner_job`, `SkillTree.quest_skill_available?/2`);
  this catalogues every skill that function already grants and are implemented in
  the catalog. A reference the function names but that has no catalog module yet
  is ignored rather than failing, so this only regresses when an implemented
  skill's `use Skill` declaration omits the metadata.
  """
  use ExUnit.Case, async: true

  alias Aesir.Net.SkillInfo
  alias Aesir.Net.SkillList
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.SkillListView
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @platinum_source Path.expand(
                     "../../../../../lib/aesir/zone_server/content/npc/functions/f_getplatinumskills.ex",
                     __DIR__
                   )

  # The generated function references implemented skills by resolved integer
  # id (`skill(ctx, 142, 1, :permanent)` or piped `|> skill(147, 1, :permanent)`)
  # and skills the transpile-time resolver could not resolve by their downcased
  # atom fallback (`skill(ctx, :mc_cartdecorate, ...)`).
  defp referenced_skill_names do
    source = File.read!(@platinum_source)

    ids =
      ~r/skill\((?:ctx, )?(\d+),/
      |> Regex.scan(source)
      |> Enum.map(fn [_full, id] -> String.to_integer(id) end)

    atoms =
      ~r/skill\((?:ctx, )?:([a-z0-9_]+),/
      |> Regex.scan(source)
      |> Enum.map(fn [_full, name] -> String.to_atom(name) end)

    Enum.uniq(ids ++ atoms)
  end

  defp catalog_lookup(skill_id) when is_integer(skill_id), do: Catalog.by_id(skill_id)
  defp catalog_lookup(name) when is_atom(name), do: Catalog.by_name(name)

  defp implemented_definitions do
    referenced_skill_names()
    |> Enum.flat_map(fn reference ->
      case catalog_lookup(reference) do
        {:ok, definition} -> [{reference, definition}]
        :error -> []
      end
    end)
  end

  test "the platinum-skill function still names its expected implemented skills" do
    implemented = implemented_definitions()

    # Locks in the 26 skills catalogued by this test's originating task; a drop
    # below this means an implemented skill regressed out of the catalog or its
    # `use Skill` name/id changed.
    assert length(implemented) >= 26
  end

  test "every implemented F_GetPlatinumSkills reference is a permanent, owned quest skill" do
    implemented = implemented_definitions()

    Enum.each(implemented, fn {reference, definition} ->
      assert definition.quest_skill,
             "#{inspect(reference)} is implemented but not marked quest_skill: true"

      assert definition.quest_owner_job,
             "#{inspect(reference)} is implemented but has no quest_owner_job"
    end)
  end

  test "references with no catalog module are ignored, not failed" do
    all_names = referenced_skill_names()
    implemented_names = implemented_definitions() |> Enum.map(&elem(&1, 0))
    unimplemented_names = all_names -- implemented_names

    assert unimplemented_names != []
    assert length(implemented_names) + length(unimplemented_names) == length(all_names)
  end

  defp progression(fields) do
    struct!(
      %PlayerProgression{
        base_level: 1,
        job_level: 1,
        job_id: 0,
        skill_point: 0,
        learned_skills: %{}
      },
      fields
    )
  end

  defp by_id(%SkillList{skills: skills}, skill_id) do
    Enum.find(skills, &(&1.skill_id == skill_id))
  end

  describe "owner id and lineage visibility" do
    test "a Novice-owned skill (NV_FIRSTAID) is visible on the Novice root and every descendant" do
      {:ok, definition} = Catalog.by_name(:nv_firstaid)
      {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)
      {:ok, hunter_id} = AvailableJobs.job_name_to_id(:hunter)

      assert SkillTree.quest_skill_available?(novice_id, definition)
      assert SkillTree.quest_skill_available?(hunter_id, definition)
    end

    test "a first-job-owned skill (AC_MAKINGARROW) stays on the Archer branch only" do
      {:ok, definition} = Catalog.by_name(:ac_makingarrow)
      {:ok, archer_id} = AvailableJobs.job_name_to_id(:archer)
      {:ok, hunter_id} = AvailableJobs.job_name_to_id(:hunter)
      {:ok, mage_id} = AvailableJobs.job_name_to_id(:mage)
      {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)

      assert SkillTree.quest_skill_available?(archer_id, definition)
      assert SkillTree.quest_skill_available?(hunter_id, definition)
      refute SkillTree.quest_skill_available?(mage_id, definition)
      refute SkillTree.quest_skill_available?(novice_id, definition)
    end

    test "a second-job-owned skill (PR_REDEMPTIO) stays on the Priest branch only" do
      {:ok, definition} = Catalog.by_name(:pr_redemptio)
      {:ok, priest_id} = AvailableJobs.job_name_to_id(:priest)
      {:ok, high_priest_id} = AvailableJobs.job_name_to_id(:high_priest)
      {:ok, acolyte_id} = AvailableJobs.job_name_to_id(:acolyte)
      {:ok, monk_id} = AvailableJobs.job_name_to_id(:monk)

      assert SkillTree.quest_skill_available?(priest_id, definition)
      assert SkillTree.quest_skill_available?(high_priest_id, definition)
      refute SkillTree.quest_skill_available?(acolyte_id, definition)
      refute SkillTree.quest_skill_available?(monk_id, definition)
    end

    test "SkillListView reports the exact owner job id for a learned first-job quest skill, gated by lineage" do
      {:ok, definition} = Catalog.by_name(:ac_makingarrow)
      {:ok, archer_id} = AvailableJobs.job_name_to_id(:archer)
      {:ok, hunter_id} = AvailableJobs.job_name_to_id(:hunter)
      learned = %{definition.id => 1}

      off_lineage = SkillListView.build(progression(learned_skills: learned))
      eligible = SkillListView.build(progression(job_id: hunter_id, learned_skills: learned))

      refute by_id(off_lineage, definition.id)

      assert %SkillInfo{job_id: ^archer_id, level: 1, upgradable: false} =
               by_id(eligible, definition.id)
    end
  end
end
