defmodule Aesir.ZoneServer.Mmo.JobManagement.LoaderTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Loader

  setup context do
    Aesir.ZoneServer.DbTestSetup.configure_root(context, "jobs")
  end

  @jobs_yaml """
  - id: 0
    name: novice
    max_weight: 20000
    max_base_level: 3
    max_job_level: 2
    base_hp: [40, 45, 50]
    base_sp: [10, 11, 12]
    base_exp: [548, 894]
    job_exp: [10]
    bonus_stats:
      - level: 2
        luk: 1
    base_aspd:
      fist: 40
      dagger: 55
  - id: 1
    name: swordman
    max_weight: 28000
    max_base_level: 2
    max_job_level: 2
    base_hp: [60, 70]
    base_sp: [10, 11]
    base_exp: [600]
    job_exp: [9]
    base_aspd:
      fist: 40
      one_handed_sword: 47
  """

  @cumulative_yaml """
  - id: 5
    name: cumulative_job
    max_weight: 1000
    max_base_level: 10
    max_job_level: 12
    base_hp: [100]
    base_sp: [10]
    base_exp: [500]
    job_exp: [9]
    bonus_stats:
      - level: 2
        str: 1
      - level: 6
        vit: 1
      - level: 10
        dex: 1
        str: 1
    base_aspd:
      fist: 40
  """

  defp write_yaml(dir, contents) do
    path = Path.join(dir, "jobs.yml")
    File.write!(path, contents)
    path
  end

  describe "load/1" do
    @tag :tmp_dir
    test "parses our-schema YAML into an index by id and name", %{tmp_dir: dir} do
      write_yaml(dir, @jobs_yaml)

      assert %{
               all: all,
               by_id: %{
                 0 => %Job{
                   name: :novice,
                   base_hp: %{1 => 40, 2 => 45, 3 => 50},
                   base_sp: %{1 => 10, 2 => 11, 3 => 12},
                   base_exp: %{1 => 548, 2 => 894},
                   job_exp: %{1 => 10},
                   max_job_level: 2
                 }
               },
               by_name: %{swordman: %Job{id: 1, base_hp: %{1 => 60, 2 => 70}}}
             } = Loader.load()

      assert length(all) == 2
    end

    @tag :tmp_dir
    test "rehydrates bonus_stats into a level-keyed map of structs", %{tmp_dir: dir} do
      write_yaml(dir, @jobs_yaml)

      assert %{
               by_id: %{0 => %Job{bonus_stats: %{2 => %Job.BonusStats{level: 2, luk: 1, str: 0}}}}
             } =
               Loader.load()
    end

    @tag :tmp_dir
    test "accumulates sparse bonus_stats into a dense per-level running total", %{tmp_dir: dir} do
      write_yaml(dir, @cumulative_yaml)

      %{by_id: %{5 => %Job{bonus_stats: bonus_stats}}} = Loader.load()

      assert %Job.BonusStats{level: 1, str: 0, vit: 0, dex: 0} = bonus_stats[1]
      assert %Job.BonusStats{level: 2, str: 1, vit: 0, dex: 0} = bonus_stats[2]
      assert %Job.BonusStats{level: 6, str: 1, vit: 1, dex: 0} = bonus_stats[6]
      assert %Job.BonusStats{level: 10, str: 2, vit: 1, dex: 1} = bonus_stats[10]
    end

    @tag :tmp_dir
    test "fills gap levels with the running total instead of leaving them missing",
         %{tmp_dir: dir} do
      write_yaml(dir, @cumulative_yaml)

      %{by_id: %{5 => %Job{bonus_stats: bonus_stats}}} = Loader.load()

      assert %Job.BonusStats{level: 7, str: 1, vit: 1, dex: 0} = bonus_stats[7]
    end

    @tag :tmp_dir
    test "extends the running total up to max_job_level beyond the last grant",
         %{tmp_dir: dir} do
      write_yaml(dir, @cumulative_yaml)

      %{by_id: %{5 => %Job{bonus_stats: bonus_stats}}} = Loader.load()

      assert %Job.BonusStats{level: 12, str: 2, vit: 1, dex: 1} = bonus_stats[12]
      refute Map.has_key?(bonus_stats, 13)
    end

    @tag :tmp_dir
    test "rehydrates base_aspd into a struct with unused weapons left nil", %{tmp_dir: dir} do
      write_yaml(dir, @jobs_yaml)

      assert %{by_id: %{0 => %Job{base_aspd: %Job.BaseAspd{fist: 40, dagger: 55, katar: nil}}}} =
               Loader.load()
    end

    @tag :tmp_dir
    test "writes a reusable .etf cache", %{tmp_dir: dir} do
      write_yaml(dir, @jobs_yaml)
      Loader.load()

      assert File.exists?(Path.join([dir, ".cache", "jobs_v2.etf"]))
    end

    @tag :tmp_dir
    test "rebuilds when a source is newer than the cache", %{tmp_dir: dir} do
      yaml = write_yaml(dir, @jobs_yaml)
      Loader.load()

      cache = Path.join([dir, ".cache", "jobs_v2.etf"])
      File.write!(yaml, String.replace(@jobs_yaml, "max_weight: 20000", "max_weight: 99999"))
      File.touch!(cache, 1_000_000)
      File.touch!(yaml, 2_000_000)

      assert %{by_id: %{0 => %Job{max_weight: 99999}}} = Loader.load()
    end

    @tag :tmp_dir
    test "raises when the domain has no base data", %{tmp_dir: _dir} do
      assert_raise RuntimeError, ~r/no renewal data for db "jobs"/, fn ->
        Loader.load()
      end
    end
  end
end
