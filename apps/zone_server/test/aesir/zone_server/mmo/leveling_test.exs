defmodule Aesir.ZoneServer.Mmo.LevelingTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  # job_id 0 == :novice (max base 99, max job 10)
  defp novice(attrs \\ %{}) do
    struct(
      PlayerProgression,
      Map.merge(%{base_level: 1, job_level: 1, base_exp: 0, job_exp: 0, job_id: 0}, attrs)
    )
  end

  test "no level up when exp is below the threshold" do
    {:ok, req} = JobManagement.get_base_exp(:novice, 1)

    {prog, base_gained, job_gained} = Leveling.apply_exp(novice(), req - 1, 0)

    assert %PlayerProgression{base_level: 1, base_exp: gained} = prog
    assert gained == req - 1
    assert base_gained == 0
    assert job_gained == 0
  end

  test "single base level up consumes the threshold and carries the remainder" do
    {:ok, req} = JobManagement.get_base_exp(:novice, 1)

    {prog, base_gained, _} = Leveling.apply_exp(novice(), req + 5, 0)

    assert %PlayerProgression{base_level: 2, base_exp: 5} = prog
    assert base_gained == 1
  end

  test "overflowing experience grants multiple base levels" do
    {:ok, r1} = JobManagement.get_base_exp(:novice, 1)
    {:ok, r2} = JobManagement.get_base_exp(:novice, 2)

    {prog, base_gained, _} = Leveling.apply_exp(novice(), r1 + r2, 0)

    assert %PlayerProgression{base_level: 3, base_exp: 0} = prog
    assert base_gained == 2
  end

  test "job experience levels the job track independently" do
    {:ok, req} = JobManagement.get_job_exp(:novice, 1)

    {prog, base_gained, job_gained} = Leveling.apply_exp(novice(), 0, req)

    assert %PlayerProgression{base_level: 1, job_level: 2, job_exp: 0} = prog
    assert base_gained == 0
    assert job_gained == 1
  end

  test "base experience is capped at the max base level" do
    {prog, base_gained, _} = Leveling.apply_exp(novice(%{base_level: 99}), 1_000_000, 0)

    assert %PlayerProgression{base_level: 99, base_exp: 0} = prog
    assert base_gained == 0
  end

  test "job experience is capped at the max job level" do
    {prog, _, job_gained} = Leveling.apply_exp(novice(%{job_level: 10}), 0, 1_000_000)

    assert %PlayerProgression{job_level: 10, job_exp: 0} = prog
    assert job_gained == 0
  end

  test "next_base_exp / next_job_exp report the current thresholds" do
    {:ok, base_req} = JobManagement.get_base_exp(:novice, 1)
    {:ok, job_req} = JobManagement.get_job_exp(:novice, 1)

    assert Leveling.next_base_exp(novice()) == base_req
    assert Leveling.next_job_exp(novice()) == job_req
    assert Leveling.next_base_exp(novice(%{base_level: 99})) == 0
  end
end
