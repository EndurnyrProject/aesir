defmodule Aesir.ZoneServer.Integration.SkillEligibilityProgressionTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.MapLoaded
  alias Aesir.Net.SkillInfo
  alias Aesir.Net.SkillList
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.JobManagement

  setup do
    stub(CharacterPersistence, :update_character, fn _id, _attrs, _opts -> {:ok, %{}} end)
    :ok
  end

  test "Novice job levels refresh Basic Skill eligibility without reconnecting" do
    player = start_player_session(class: 0, job_level: 1, skill_point: 0)
    Mimic.allow(CharacterPersistence, self(), player.pid)
    simulate_incoming_message(player.pid, %MapLoaded{})

    assert %SkillList{skills: initial_skills} = assert_packet_sent(SkillList)
    assert %SkillInfo{level: 0, max_level: 9, upgradable: false} = basic_skill(initial_skills)

    PlayerSession.add_job_level(player.pid, 9)

    assert_eventually(fn ->
      progression = get_player_state(player.pid).stats.progression
      progression.job_level == 10 and progression.skill_point == 9
    end)

    assert %SkillList{skills: updated_skills} = assert_packet_sent(SkillList)
    assert %SkillInfo{level: 0, max_level: 9, upgradable: true} = basic_skill(updated_skills)

    end_player_session(player)
  end

  test "combat job level-up refreshes eligibility but ordinary EXP ticks do not" do
    player = start_player_session(class: 0, job_level: 1, skill_point: 0)
    Mimic.allow(CharacterPersistence, self(), player.pid)
    simulate_incoming_message(player.pid, %MapLoaded{})
    assert %SkillList{} = assert_packet_sent(SkillList)
    {:ok, job_exp} = JobManagement.get_job_exp(:novice, 1)

    send(player.pid, {:progression, {:mob_kill_exp, 0, job_exp, nil, nil}})

    assert %SkillList{skills: skills} = assert_packet_sent(SkillList)
    assert %SkillInfo{level: 0, upgradable: true} = basic_skill(skills)
    progression = get_player_state(player.pid).stats.progression
    assert progression.job_level == 2
    assert progression.skill_point == 1

    send(player.pid, {:progression, {:mob_kill_exp, 0, 1, nil, nil}})

    assert_eventually(fn -> get_player_state(player.pid).stats.progression.job_exp == 1 end)
    refute_packet_sent(SkillList)

    end_player_session(player)
  end

  defp basic_skill(skills), do: Enum.find(skills, &(&1.name == "NV_BASIC"))
end
