defmodule Aesir.ZoneServer.Mmo.SkillTreeWizardTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.SkillTree.Entry
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  {:ok, wizard_id} = AvailableJobs.job_name_to_id(:wizard)
  @wizard_id wizard_id

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp wizard_progression(attrs) do
    Map.merge(
      %PlayerProgression{
        base_level: 99,
        job_level: 50,
        base_exp: 0,
        job_exp: 0,
        job_id: @wizard_id,
        skill_point: 1,
        status_point: 0,
        learned_skills: %{}
      },
      Map.new(attrs)
    )
  end

  defp wizard_entry(skill, requires) do
    %Entry{
      skill_id: catalog_id(skill),
      owner_job_id: @wizard_id,
      max_level: 10,
      requires: requires
    }
  end

  test "Frost Nova requires Ice Wall level 1" do
    ice_wall = catalog_id(:wz_icewall)
    entry = wizard_entry(:wz_frostnova, [{ice_wall, 1}])

    assert {:error, :missing_prerequisite} =
             SkillTree.can_learn_entry(
               wizard_progression(learned_skills: %{ice_wall => 0}),
               entry
             )

    assert :ok =
             SkillTree.can_learn_entry(
               wizard_progression(learned_skills: %{ice_wall => 1}),
               entry
             )
  end

  test "Heaven's Drive requires Earth Spike level 3" do
    earth_spike = catalog_id(:wz_earthspike)
    entry = wizard_entry(:wz_heavendrive, [{earth_spike, 3}])

    assert {:error, :missing_prerequisite} =
             SkillTree.can_learn_entry(
               wizard_progression(learned_skills: %{earth_spike => 2}),
               entry
             )

    assert :ok =
             SkillTree.can_learn_entry(
               wizard_progression(learned_skills: %{earth_spike => 3}),
               entry
             )
  end
end
