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

    assert %PlayerProgression{base_level: 99, base_exp: 1_000_000} = prog
    assert base_gained == 0
  end

  test "job experience is capped at the max job level" do
    {prog, _, job_gained} = Leveling.apply_exp(novice(%{job_level: 10}), 0, 1_000_000)

    assert %PlayerProgression{job_level: 10, job_exp: 1_000_000} = prog
    assert job_gained == 0
  end

  test "exp gained at max level accumulates up to the max-level exp limit" do
    near_cap =
      novice(%{base_level: 99, job_level: 10, base_exp: 99_999_000, job_exp: 999_999_000})

    at_cap = novice(%{base_level: 99, job_level: 10, base_exp: 99_999_999, job_exp: 999_999_999})

    assert {%PlayerProgression{base_exp: 99_999_999, job_exp: 999_999_999}, 0, 0} =
             Leveling.apply_exp(near_cap, 5_000, 5_000)

    assert {%PlayerProgression{base_exp: 99_999_999, job_exp: 999_999_999}, 0, 0} =
             Leveling.apply_exp(at_cap, 5_000, 5_000)
  end

  test "a level-up into max level keeps the overflow, clamped to the limit" do
    {:ok, base_req} = JobManagement.get_base_exp(:novice, 98)
    {:ok, job_req} = JobManagement.get_job_exp(:novice, 9)
    prog = novice(%{base_level: 98, job_level: 9})

    assert {%PlayerProgression{base_level: 99, job_level: 10, base_exp: 7, job_exp: 9}, 1, 1} =
             Leveling.apply_exp(prog, base_req + 7, job_req + 9)

    assert {%PlayerProgression{base_exp: 99_999_999, job_exp: 999_999_999}, 1, 1} =
             Leveling.apply_exp(prog, base_req + 200_000_000, job_req + 2_000_000_000)
  end

  test "next_base_exp / next_job_exp report the current thresholds" do
    {:ok, base_req} = JobManagement.get_base_exp(:novice, 1)
    {:ok, job_req} = JobManagement.get_job_exp(:novice, 1)

    assert Leveling.next_base_exp(novice()) == base_req
    assert Leveling.next_job_exp(novice()) == job_req
    assert Leveling.next_base_exp(novice(%{base_level: 99})) == 99_999_999
  end

  test "next_job_exp at max job level is the max-level exp limit" do
    assert Leveling.next_job_exp(novice(%{job_level: 10})) == 999_999_999
  end

  describe "death_penalty/3" do
    test "loses the configured percent of the next-level exp when exp allows" do
      {:ok, base_req} = JobManagement.get_base_exp(:novice, 1)
      {:ok, job_req} = JobManagement.get_job_exp(:novice, 1)

      prog = novice(%{base_exp: base_req, job_exp: job_req})

      assert {div(base_req, 100), div(job_req, 100)} == Leveling.death_penalty(prog, 100, 100)
    end

    test "never de-levels: caps at the current exp into the level" do
      {:ok, base_req} = JobManagement.get_base_exp(:novice, 1)

      prog = novice(%{base_exp: 5, job_exp: 3})
      {base_loss, job_loss} = Leveling.death_penalty(prog, 100, 100)

      assert base_loss <= 5
      assert job_loss <= 3
      assert base_loss == min(5, div(base_req, 100))
    end

    test "a fresh level with zero exp loses nothing" do
      assert {0, 0} == Leveling.death_penalty(novice(), 100, 100)
    end

    test "at the level cap there is no next-level exp so no loss" do
      prog = novice(%{base_level: 99, job_level: 10, base_exp: 0, job_exp: 0})

      assert {0, 0} == Leveling.death_penalty(prog, 100, 100)
    end

    test "a zero rate yields no loss on that track" do
      {:ok, base_req} = JobManagement.get_base_exp(:novice, 1)
      {:ok, job_req} = JobManagement.get_job_exp(:novice, 1)
      prog = novice(%{base_exp: base_req, job_exp: job_req})

      assert {0, div(job_req, 100)} == Leveling.death_penalty(prog, 0, 100)
      assert {div(base_req, 100), 0} == Leveling.death_penalty(prog, 100, 0)
      assert {0, 0} == Leveling.death_penalty(prog, 0, 0)
    end

    test "the loss is never negative" do
      prog = novice(%{base_exp: 0, job_exp: 0})
      {base_loss, job_loss} = Leveling.death_penalty(prog, 500, 500)

      assert base_loss >= 0
      assert job_loss >= 0
    end
  end

  describe "death_penalty/5" do
    test "takes rate/10000 of the next-level exp (type 1) or of the exp held (type 2), truncated" do
      {:ok, base_req} = JobManagement.get_base_exp(:novice, 5)
      {:ok, job_req} = JobManagement.get_job_exp(:novice, 5)
      prog = novice(%{base_level: 5, job_level: 5, base_exp: 1234, job_exp: 1000})

      for {type, base_rate, job_rate, expected} <- [
            {1, 150, 0, {min(1234, trunc(base_req * 0.015)), 0}},
            {1, 0, 10_000, {0, min(1000, job_req)}},
            {2, 150, 150, {18, 15}},
            {2, 33, 1, {4, 0}},
            {2, 20_000, 20_000, {1234, 1000}}
          ] do
        assert expected == Leveling.death_penalty(prog, type, base_rate, job_rate, 0),
               "type #{type} rates #{base_rate}/#{job_rate}"
      end
    end

    test "at max level only the tracks allowed by maxlv lose exp, against the max-level limit" do
      capped = novice(%{base_level: 99, job_level: 10, base_exp: 5_000_000, job_exp: 9_000_000})

      for {type, maxlv, expected} <- [
            {1, 0, {0, 0}},
            {1, 1, {999_999, 0}},
            {1, 2, {0, 9_000_000}},
            {2, 3, {50_000, 90_000}}
          ] do
        assert expected == Leveling.death_penalty(capped, type, 100, 100, maxlv),
               "type #{type} maxlv #{maxlv}"
      end
    end

    test "exp gained at max level is what a later death takes from" do
      {gained, 0, 0} =
        Leveling.apply_exp(novice(%{base_level: 99, job_level: 10}), 5_000_000, 9_000_000)

      for {type, maxlv, expected} <- [
            {1, 0, {0, 0}},
            {1, 1, {999_999, 0}},
            {1, 2, {0, 9_000_000}},
            {1, 3, {999_999, 9_000_000}},
            {2, 0, {0, 0}},
            {2, 1, {50_000, 0}},
            {2, 2, {0, 90_000}},
            {2, 3, {50_000, 90_000}}
          ] do
        assert expected == Leveling.death_penalty(gained, type, 100, 100, maxlv),
               "type #{type} maxlv #{maxlv}"
      end
    end
  end
end
