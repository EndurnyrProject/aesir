defmodule Aesir.ZoneServer.Mmo.JobManagement.TraitJobsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.JobManagement.TraitJobs
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  describe "trait_job?/1" do
    test "true for a 4th-job id" do
      assert TraitJobs.trait_job?(4252)
    end

    test "true for an alt-sprite (mounted) 4th-job id" do
      assert TraitJobs.trait_job?(4278)
    end

    test "false for a 3rd-job id" do
      refute TraitJobs.trait_job?(4054)
    end
  end

  describe "change_allowed?/2" do
    test "ok for the right parent at base 200 / job 70" do
      progression = %PlayerProgression{job_id: 4054, base_level: 200, job_level: 70}

      assert TraitJobs.change_allowed?(progression, 4252) == :ok
    end

    test "error for a job id that is not a listed parent of the target" do
      progression = %PlayerProgression{job_id: 4055, base_level: 200, job_level: 70}

      assert TraitJobs.change_allowed?(progression, 4252) == {:error, :requirements_not_met}
    end

    test "error when base level is below 200" do
      progression = %PlayerProgression{job_id: 4054, base_level: 199, job_level: 70}

      assert TraitJobs.change_allowed?(progression, 4252) == {:error, :requirements_not_met}
    end

    test "error when job level is below the parent's max_job_level" do
      progression = %PlayerProgression{job_id: 4054, base_level: 200, job_level: 69}

      assert TraitJobs.change_allowed?(progression, 4252) == {:error, :requirements_not_met}
    end

    test "ok for a summoner parent (max_job_level 60) at base 200 / job 60" do
      progression = %PlayerProgression{job_id: 4218, base_level: 200, job_level: 60}

      assert TraitJobs.change_allowed?(progression, 4308) == :ok
    end

    test "always ok for a non-trait target job" do
      progression = %PlayerProgression{job_id: 1, base_level: 1, job_level: 1}

      assert TraitJobs.change_allowed?(progression, 7) == :ok
    end

    test "error for an alt-variant trait id (not an eligibility key), even when otherwise capped" do
      progression = %PlayerProgression{job_id: 4054, base_level: 200, job_level: 70}

      assert TraitJobs.change_allowed?(progression, 4280) == {:error, :requirements_not_met}
    end
  end
end
