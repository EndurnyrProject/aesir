defmodule Aesir.ZoneServer.Gm.Commands.JobTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Gm.Commands.Job
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Phoenix.PubSub

  @char_id 4242

  defp ctx do
    %{
      game_state: %PlayerState{character_id: @char_id, character_name: "Gm"},
      connection_pid: self()
    }
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
    assert_receive {:change_job, 7}
  end

  test "valid job name broadcasts {:change_job, id} on the caller's topic" do
    PubSub.subscribe(Aesir.PubSub, "player:#{@char_id}")

    assert {:ok, "Changed job to knight (7)"} = Job.execute(["Knight"], ctx())
    assert_receive {:change_job, 7}
  end
end
