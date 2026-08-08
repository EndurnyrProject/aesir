defmodule Aesir.ZoneServer.Unit.Player.SkillListViewTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import Mimic

  alias Aesir.Net.SkillInfo
  alias Aesir.Net.SkillList
  alias Aesir.Net.SkillRequirement
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SkillListView
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @novice_job_id 0
  @swordman_job_id 1
  @sm_sword_id 2
  @sm_twohand_id 3
  @sm_bash_id 5
  @acolyte_job_id 4
  @al_heal_id 28
  @mage_job_id 2
  @mg_thunderstorm_id 21
  @archer_job_id 3
  @hunter_job_id 11
  @quest_skill_id 99_022
  @quest_definition Definition.build!(
                      [
                        id: @quest_skill_id,
                        name: :fixture_archer_quest,
                        display_name: "Fixture Archer Quest",
                        max_level: 1,
                        target_type: :self,
                        sp_cost: [7],
                        quest_skill: true,
                        quest_owner_job: :archer
                      ],
                      __MODULE__
                    )

  defp stub_quest_definition do
    stub(Catalog, :by_id, fn
      @quest_skill_id -> {:ok, @quest_definition}
      skill_id -> call_original(Catalog, :by_id, [skill_id])
    end)
  end

  defp progression(fields) do
    struct!(
      %PlayerProgression{
        base_level: 1,
        job_level: 1,
        job_id: @swordman_job_id,
        skill_point: 0,
        learned_skills: %{}
      },
      fields
    )
  end

  defp by_id(%SkillList{skills: skills}, skill_id) do
    Enum.find(skills, &(&1.skill_id == skill_id))
  end

  describe "build/1" do
    test "a Swordman with no points lists its tree entries at level 0, not upgradable" do
      %SkillList{skills: skills} = SkillListView.build(progression(skill_point: 0))

      # The Swordman tree's point-learnable entries are 7 SM_* skills plus
      # NV_BASIC inherited from the Novice tree; quest skills (NV_FIRSTAID,
      # NV_TRICKDEAD, SM_MOVINGRECOVERY, SM_FATALBLOW, SM_AUTOBERSERK) are
      # grant-only and hidden until learned.
      assert length(skills) == 8
      assert Enum.count(skills, &String.starts_with?(&1.name, "SM_")) == 7
      assert Enum.count(skills, &String.starts_with?(&1.name, "NV_")) == 1
      assert Enum.all?(skills, &(&1.level == 0))
      assert Enum.all?(skills, &(&1.upgradable == false))
    end

    test "maps max_level, name (upcased), and requires to SkillRequirement" do
      list = SkillListView.build(progression(skill_point: 0))

      sword = by_id(list, @sm_sword_id)
      assert %SkillInfo{max_level: 10, name: "SM_SWORD", requires: []} = sword

      twohand = by_id(list, @sm_twohand_id)
      assert %SkillInfo{requires: [%SkillRequirement{skill_id: @sm_sword_id, level: 1}]} = twohand
    end

    test "carries the tree level minimums as req_base_level / req_job_level" do
      sword = SkillListView.build(progression(skill_point: 0)) |> by_id(@sm_sword_id)
      assert sword.req_base_level == 0
      assert sword.req_job_level == 0
    end

    test "job_id carries the owning job: own skills the viewing job, inherited the parent" do
      %SkillList{skills: skills} = SkillListView.build(progression(skill_point: 0))

      assert Enum.all?(skills, fn skill ->
               case skill.name do
                 "SM_" <> _ -> skill.job_id == @swordman_job_id
                 "NV_" <> _ -> skill.job_id == @novice_job_id
               end
             end)
    end

    test "an available skill with a point and met prereqs is upgradable" do
      sword = SkillListView.build(progression(skill_point: 1)) |> by_id(@sm_sword_id)
      assert sword.upgradable == true
    end

    test "an available skill with an unmet prerequisite is not upgradable" do
      # SM_TWOHAND requires SM_SWORD lv 1, which is not learned.
      twohand = SkillListView.build(progression(skill_point: 1)) |> by_id(@sm_twohand_id)
      assert twohand.upgradable == false
    end

    test "an unlearned skill (level 0) has sp 0, not the Enum.at(-1) last element" do
      # SM_BASH sp_cost is [8,8,8,8,8,15,...]; the old Enum.at(0 - 1) bug would
      # return the last element (15) for an unlearned skill.
      bash = SkillListView.build(progression(skill_point: 0)) |> by_id(@sm_bash_id)
      assert bash.level == 0
      assert bash.sp == 0
    end

    test "a learned skill reports its level and the cast cost for that level" do
      # SM_BASH at level 6 casts for sp_cost[5] == 15.
      list = SkillListView.build(progression(learned_skills: %{@sm_bash_id => 6}))
      bash = by_id(list, @sm_bash_id)
      assert bash.level == 6
      assert bash.sp == 15
    end

    test "a :target_any skill (AL_HEAL) maps to the target-select type without crashing" do
      heal =
        progression(job_id: @acolyte_job_id)
        |> SkillListView.build()
        |> by_id(@al_heal_id)

      assert %SkillInfo{name: "AL_HEAL", type: 16} = heal
    end

    test "an area skill (MG_THUNDERSTORM) carries its splash_radius" do
      thunderstorm =
        progression(job_id: @mage_job_id)
        |> SkillListView.build()
        |> by_id(@mg_thunderstorm_id)

      assert %SkillInfo{splash_radius: 2} = thunderstorm
    end

    test "a retained quest skill uses its exact owner id and follows lineage visibility" do
      stub_quest_definition()
      learned = %{@quest_skill_id => 1}

      off_lineage = SkillListView.build(progression(learned_skills: learned))
      eligible = SkillListView.build(progression(job_id: @hunter_job_id, learned_skills: learned))

      refute by_id(off_lineage, @quest_skill_id)

      assert %SkillInfo{job_id: @archer_job_id, level: 1, upgradable: false} =
               by_id(eligible, @quest_skill_id)
    end

    test "includes the copied skill as a castable entry" do
      state = %PlayerState{
        stats: %{progression: progression(skill_point: 0)},
        plagiarized: %{skill_id: @mg_thunderstorm_id, level: 4}
      }

      assert %SkillInfo{
               skill_id: @mg_thunderstorm_id,
               level: 4,
               type: 2,
               upgradable: false,
               requires: []
             } = SkillListView.build(state) |> by_id(@mg_thunderstorm_id)
    end

    test "a non-area skill (SM_SWORD) reports splash_radius 0" do
      sword = SkillListView.build(progression(skill_point: 0)) |> by_id(@sm_sword_id)
      assert sword.splash_radius == 0
    end
  end
end
