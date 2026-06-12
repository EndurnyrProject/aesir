defmodule Aesir.ZoneServer.Mmo.JobManagement.JobsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Jobs

  # Jobs present in the base-point/stat data but absent from the exp curves in
  # the source data. They legitimately have no exp tables.
  @jobs_without_exp [:sky_emperor2]

  @dense_value_tables [:base_hp, :base_sp, :base_ap, :base_exp, :job_exp]

  describe "registry" do
    test "exposes every job module" do
      assert length(Jobs.modules()) == length(Jobs.all())
      assert length(Jobs.modules()) > 0
    end

    test "all job ids are unique" do
      ids = Enum.map(Jobs.all(), & &1.id)
      assert length(ids) == length(Enum.uniq(ids))
    end

    test "all job names are unique" do
      names = Enum.map(Jobs.all(), & &1.name)
      assert length(names) == length(Enum.uniq(names))
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

    test "unknown id and name return :error" do
      assert :error = Jobs.by_id(-1)
      assert :error = Jobs.by_name(:not_a_real_job)
    end
  end

  describe "data invariants" do
    test "every job has a base exp and a job exp table (except documented exceptions)" do
      for %Job{name: name} = job <- Jobs.all(), name not in @jobs_without_exp do
        assert map_size(job.base_exp) > 0, "#{name} is missing base_exp"
        assert map_size(job.job_exp) > 0, "#{name} is missing job_exp"
      end
    end

    test "dense level tables have no gaps between their first and last level" do
      for job <- Jobs.all(), key <- @dense_value_tables do
        table = Map.fetch!(job, key)

        if map_size(table) > 0 do
          levels = table |> Map.keys() |> Enum.sort()
          expected = Enum.to_list(Enum.min(levels)..Enum.max(levels))

          assert levels == expected,
                 "#{job.name} #{key} has gaps: #{inspect(expected -- levels)}"
        end
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

    test "bonus stats are keyed by their own level and stored as structs" do
      for job <- Jobs.all(), {level, stats} <- job.bonus_stats do
        assert is_integer(level)
        assert %Job.BonusStats{} = stats
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

    test "reads weapon aspd and reports unknown weapon types" do
      assert {:ok, 5} = JobManagement.get_base_aspd(:swordman, :shield)
      assert {:error, :weapon_type_not_found} = JobManagement.get_base_aspd(:swordman, :huuma)
    end

    test "bonus stats preserve the highest-entry-<=-level semantics" do
      assert {:ok, %Job.BonusStats{level: 9, int: 1}} =
               JobManagement.get_bonus_stats(:novice, 9)

      assert {:ok, %Job.BonusStats{level: 8, str: 1}} =
               JobManagement.get_bonus_stats(:novice, 8)
    end

    test "validates base and job levels against the job maxima" do
      assert JobManagement.is_valid_base_level?(:novice, 1)
      refute JobManagement.is_valid_base_level?(:novice, 0)
      refute JobManagement.is_valid_job_level?(:novice, 9_999)
    end
  end
end
