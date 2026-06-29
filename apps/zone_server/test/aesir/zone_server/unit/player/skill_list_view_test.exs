defmodule Aesir.ZoneServer.Unit.Player.SkillListViewTest do
  use ExUnit.Case, async: true

  @moduletag :capture_log

  alias Aesir.Net.SkillInfo
  alias Aesir.Net.SkillList
  alias Aesir.Net.SkillRequirement
  alias Aesir.ZoneServer.Unit.Player.SkillListView
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @novice_job_id 0
  @swordman_job_id 1
  @sm_sword_id 2
  @sm_twohand_id 3
  @sm_bash_id 5
  @acolyte_job_id 4
  @al_heal_id 28

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

      # The Swordman tree's implemented entries are the 10 SM_* skills plus the
      # two implemented Novice skills inherited from the Novice tree
      # (NV_FIRSTAID, NV_TRICKDEAD); the rest of the Novice tree is unimplemented
      # and filtered out by the loader.
      assert length(skills) == 12
      assert Enum.count(skills, &String.starts_with?(&1.name, "SM_")) == 10
      assert Enum.count(skills, &String.starts_with?(&1.name, "NV_")) == 2
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
  end
end
