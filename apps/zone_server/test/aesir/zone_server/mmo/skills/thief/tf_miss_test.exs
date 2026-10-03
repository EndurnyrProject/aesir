defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfMissTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfMiss

  test "flee_bonus is 3 * level" do
    assert TfMiss.flee_bonus(1, %{}) == 3
    assert TfMiss.flee_bonus(10, %{}) == 30
    {:ok, thief_id} = AvailableJobs.job_name_to_id(:thief)
    assert TfMiss.flee_bonus(10, %{job_id: thief_id}) == 30
  end

  test "flee_bonus is 4 * level for a second class of the thief branch" do
    {:ok, assassin_id} = AvailableJobs.job_name_to_id(:assassin)
    {:ok, rogue_id} = AvailableJobs.job_name_to_id(:rogue)
    {:ok, knight_id} = AvailableJobs.job_name_to_id(:knight)
    assert TfMiss.flee_bonus(10, %{job_id: assassin_id}) == 40
    assert TfMiss.flee_bonus(10, %{job_id: rogue_id}) == 40
    assert TfMiss.flee_bonus(10, %{job_id: knight_id}) == 30
  end
end
