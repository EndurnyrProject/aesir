defmodule Aesir.ZoneServer.Gm.Commands.JobTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Gm.Commands.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats
  alias Phoenix.PubSub

  @char_id 4242

  {:ok, rune_knight_id} = AvailableJobs.job_name_to_id(:rune_knight)
  @rune_knight_id rune_knight_id
  {:ok, dragon_knight_id} = AvailableJobs.job_name_to_id(:dragon_knight)
  @dragon_knight_id dragon_knight_id

  defp ctx(overrides \\ [], progression_overrides \\ []) do
    progression =
      struct(%PlayerProgression{job_id: 0, base_level: 1, job_level: 1}, progression_overrides)

    stats = %Stats{progression: progression}

    game_state =
      struct(%PlayerState{character_id: @char_id, character_name: "Gm", stats: stats}, overrides)

    %{game_state: game_state, connection_pid: self()}
  end

  test "name and required_level" do
    assert Job.name() == "job"
    assert Job.required_level() == 60
  end

  describe "arg validation" do
    test "missing args" do
      assert {:error, "Usage: @job <job_id | job_name>"} = Job.execute([], ctx())
    end

    test "unknown job id" do
      assert {:error, "Unknown job"} = Job.execute(["99999"], ctx())
    end

    test "unknown job name" do
      assert {:error, "Unknown job"} = Job.execute(["definitely_not_a_job"], ctx())
    end
  end

  test "valid numeric id broadcasts {:change_job, id} on the caller's topic" do
    PubSub.subscribe(Aesir.PubSub, "player:#{@char_id}")

    assert {:ok, "Changed job to knight (7)"} = Job.execute(["7"], ctx())
    assert_receive {:progression, {:change_job, 7}}
  end

  test "valid job name broadcasts {:change_job, id} on the caller's topic" do
    PubSub.subscribe(Aesir.PubSub, "player:#{@char_id}")

    assert {:ok, "Changed job to knight (7)"} = Job.execute(["Knight"], ctx())
    assert_receive {:progression, {:change_job, 7}}
  end

  test "is rejected with a message when a mounted cart would be dropped, broadcasting nothing" do
    PubSub.subscribe(Aesir.PubSub, "player:#{@char_id}")

    assert {:error, "Remove your cart before changing job"} =
             Job.execute(["7"], ctx(cart_type: 1))

    refute_receive {:progression, {:change_job, 7}}
  end

  test "is rejected with a message when 4th-job requirements are not met, broadcasting nothing" do
    PubSub.subscribe(Aesir.PubSub, "player:#{@char_id}")

    ineligible = ctx([], job_id: @rune_knight_id, base_level: 100, job_level: 50)

    assert {:error, "You do not meet the requirements for that job"} =
             Job.execute([to_string(@dragon_knight_id)], ineligible)

    refute_receive {:progression, {:change_job, _}}
  end

  test "allows an eligible 4th-job change, broadcasting {:change_job, id}" do
    PubSub.subscribe(Aesir.PubSub, "player:#{@char_id}")

    eligible = ctx([], job_id: @rune_knight_id, base_level: 200, job_level: 70)

    assert {:ok, _} = Job.execute([to_string(@dragon_knight_id)], eligible)
    assert_receive {:progression, {:change_job, @dragon_knight_id}}
  end
end
