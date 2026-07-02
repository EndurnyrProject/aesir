defmodule Aesir.ZoneServer.Mmo.JobManagement.JobChangeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.JobManagement.JobChange
  alias Phoenix.PubSub

  test "valid job id broadcasts {:change_job, id} to the player topic and returns :ok" do
    char_id = 1001
    PubSub.subscribe(Aesir.PubSub, "player:#{char_id}")

    assert :ok = JobChange.request(char_id, 7)
    assert_receive {:change_job, 7}
  end

  test "unknown job id returns an error and broadcasts nothing" do
    char_id = 1002
    PubSub.subscribe(Aesir.PubSub, "player:#{char_id}")

    assert {:error, :unknown_job} = JobChange.request(char_id, 99_999)
    refute_receive {:change_job, _}
  end
end
