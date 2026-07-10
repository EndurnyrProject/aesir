defmodule Aesir.ZoneServer.Integration.SkillLearningTest do
  @moduledoc """
  End-to-end skill-learning loop: gaining a job level grants a skill point, and
  spending it on a tree skill raises that skill's level, decrements the point,
  syncs the enriched `SkillList`, and persists the learned skills.

  Drives the real `ExperienceHandler` -> `Leveling` -> `SkillLearningHandler` ->
  `SkillTree` path; only the I/O collaborators (persistence, registry, client
  sync) are stubbed.
  """
  use ExUnit.Case, async: true

  @moduletag :integration
  import Mimic

  alias Aesir.Net.SkillList
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillLearningHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  setup :verify_on_exit!

  {:ok, swordman_id} = AvailableJobs.job_name_to_id(:swordman)
  @swordman_id swordman_id

  # Job exp required to advance a level-1 Swordman to job level 2; exactly one
  # job level-up, which grants exactly one skill point.
  {:ok, one_job_level_exp} = JobManagement.get_job_exp(:swordman, 1)
  @one_job_level_exp one_job_level_exp

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp fresh_swordman_state do
    base = PlayerState.new(character())

    stats =
      base.stats
      |> put_in([Access.key!(:progression), Access.key!(:job_id)], @swordman_id)
      |> put_in([Access.key!(:progression), Access.key!(:base_level)], 10)
      |> put_in([Access.key!(:progression), Access.key!(:job_level)], 1)
      |> put_in([Access.key!(:progression), Access.key!(:base_exp)], 0)
      |> put_in([Access.key!(:progression), Access.key!(:job_exp)], 0)
      |> put_in([Access.key!(:progression), Access.key!(:skill_point)], 0)
      |> put_in([Access.key!(:progression), Access.key!(:learned_skills)], %{})

    %{connection_pid: self(), game_state: %{base | stats: stats}}
  end

  defp character do
    %Aesir.Commons.Models.Character{
      id: 1000,
      account_id: 2000,
      name: "Swordy",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 10,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 10,
      job_level: 1,
      class: 1
    }
  end

  describe "gain job exp then learn a skill" do
    test "a job level-up grants a point that learning SM_SWORD spends" do
      sword_id = catalog_id(:sm_sword)

      stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
      stub(StatusSync, :send_params, fn _conn, _params -> :ok end)

      stub(CharacterPersistence, :update_character, fn 1000, attrs, async: true ->
        send(self(), {:persisted, attrs})
        {:ok, %{}}
      end)

      {:noreply, leveled_state} =
        ExperienceHandler.handle_gain_exp(0, @one_job_level_exp, fresh_swordman_state())

      assert leveled_state.game_state.stats.progression.job_level == 2
      assert leveled_state.game_state.stats.progression.skill_point >= 1

      points_before = leveled_state.game_state.stats.progression.skill_point

      {:noreply, learned_state} =
        SkillLearningHandler.handle_learn_skill(sword_id, leveled_state)

      progression = learned_state.game_state.stats.progression
      assert progression.skill_point == points_before - 1
      assert progression.learned_skills[sword_id] == 1

      assert_received {:send, :bulk, {:skill_list, %SkillList{skills: skills}}}
      sword_info = Enum.find(skills, &(&1.skill_id == sword_id))
      assert sword_info.name == "SM_SWORD"
      assert sword_info.level == 1

      assert_received {:persisted,
                       %{
                         learned_skills: learned_dump,
                         skill_point: persisted_points
                       }}

      assert learned_dump == %{Integer.to_string(sword_id) => 1}
      assert persisted_points == points_before - 1
    end
  end
end
