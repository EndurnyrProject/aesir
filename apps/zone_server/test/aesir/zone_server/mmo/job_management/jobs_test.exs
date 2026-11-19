defmodule Aesir.ZoneServer.Mmo.JobManagement.JobsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Jobs

  describe "registry" do
    @tag game_mode: :renewal
    test "loads the Renewal job set through fourth jobs" do
      assert {:ok, %Job{name: :dragon_knight}} = Jobs.by_name(:dragon_knight)
    end

    @tag game_mode: :pre_renewal
    test "loads the trans-era job set without fourth jobs" do
      assert {:ok, %Job{name: :lord_knight}} = Jobs.by_name(:lord_knight)
      assert :error = Jobs.by_name(:dragon_knight)
    end

    test "by_id resolves every job to the same struct as the registry" do
      for %Job{id: id} = job <- Jobs.all() do
        assert {:ok, ^job} = Jobs.by_id(id)
      end
    end

    test "by_name resolves every job to the same struct as the registry" do
      for %Job{name: name} = job <- Jobs.all() do
        assert {:ok, ^job} = Jobs.by_name(name)
      end
    end
  end

  describe "data invariants" do
    test "every job has a base exp and a job exp table" do
      for %Job{name: name} = job <- Jobs.all() do
        assert map_size(job.base_exp) > 0, "#{name} is missing base_exp"
        assert map_size(job.job_exp) > 0, "#{name} is missing job_exp"
      end
    end

    test "max_base_level matches the top of the base exp table" do
      for job <- Jobs.all(), map_size(job.base_exp) > 0 do
        assert job.max_base_level == job.base_exp |> Map.keys() |> Enum.max()
      end
    end

    test "max_job_level matches the top of the job exp table" do
      for job <- Jobs.all(), map_size(job.job_exp) > 0 do
        assert job.max_job_level == job.job_exp |> Map.keys() |> Enum.max()
      end
    end
  end

  describe "public API faithfulness" do
    test "resolves known jobs by id and name" do
      assert {:ok, %Job{id: 0, name: :novice}} = JobManagement.get_job_by_id(0)
      assert {:ok, %Job{id: 1, name: :swordman}} = JobManagement.get_job_by_name(:swordman)
    end

    test "returns :job_not_found for unknown jobs" do
      assert {:error, :job_not_found} = JobManagement.get_job_by_id(-1)
      assert {:error, :job_not_found} = JobManagement.get_job_by_name(:not_a_real_job)
    end

    test "looks up base hp/sp by exact level" do
      assert {:ok, 40} = JobManagement.get_base_hp(:novice, 1)
      assert {:ok, 11} = JobManagement.get_base_sp(:novice, 1)
    end

    test "returns :level_out_of_range for a missing level in a populated table" do
      assert {:error, :level_out_of_range} = JobManagement.get_base_hp(:novice, 9_999)
    end

    @tag game_mode: :renewal
    test "reads Renewal weapon ASPD entries" do
      assert {:ok, 47} = JobManagement.get_base_aspd(:swordman, :one_handed_sword)
      assert {:ok, 5} = JobManagement.get_base_aspd(:swordman, :shield)
    end

    @tag game_mode: :pre_renewal
    test "reads classic weapon delays without a shield entry" do
      assert {:ok, 550} = JobManagement.get_base_aspd(:swordman, :one_handed_sword)
      assert {:error, :weapon_type_not_found} = JobManagement.get_base_aspd(:swordman, :shield)
    end

    test "reports unknown weapon types" do
      assert {:error, :weapon_type_not_found} = JobManagement.get_base_aspd(:swordman, :huuma)
    end

    test "bonus stats accumulate every prior grant into the running total" do
      assert {:ok, %Job.BonusStats{level: 10, str: 1, vit: 1, dex: 1, agi: 0, int: 0, luk: 0}} =
               JobManagement.get_bonus_stats(:swordman, 10)
    end

    @tag game_mode: :renewal
    test "trait job bonus stats sum pow/sta/... up to the max job level" do
      assert {:ok, %Job.BonusStats{level: 60, pow: 10, sta: 7, wis: 3, spl: 5, con: 7, crt: 8}} =
               JobManagement.get_bonus_stats(:dragon_knight, 60)
    end

    @tag game_mode: :pre_renewal
    test "trait job bonus stats are unavailable with the classic job corpus" do
      assert {:error, :job_not_found} = JobManagement.get_bonus_stats(:dragon_knight, 60)
    end

    test "validates base and job levels against the job maxima" do
      assert JobManagement.is_valid_base_level?(:novice, 1)
      refute JobManagement.is_valid_base_level?(:novice, 0)
      refute JobManagement.is_valid_job_level?(:novice, 9_999)
    end
  end
end
