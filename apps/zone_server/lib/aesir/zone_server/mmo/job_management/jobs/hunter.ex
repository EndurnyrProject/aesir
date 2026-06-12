defmodule Aesir.ZoneServer.Mmo.JobManagement.Jobs.Hunter do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.JobManagement.Definition

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Tables

  @impl true
  def job do
    %Job{
      id: 11,
      name: :hunter,
      base_hp: Tables.BasepointsBabyHunter.base_hp(),
      base_sp: Tables.BasepointsBabyHunter.base_sp(),
      base_ap: Tables.BasepointsBabyHunter.base_ap(),
      base_exp: Tables.ExpAlchemist.base_exp(),
      job_exp: Tables.ExpAlchemist.job_exp(),
      bonus_stats: %{
        1 => %Job.BonusStats{level: 1, dex: 1},
        2 => %Job.BonusStats{level: 1, dex: 1},
        3 => %Job.BonusStats{level: 3, int: 1},
        4 => %Job.BonusStats{level: 4, dex: 1},
        5 => %Job.BonusStats{level: 5, luk: 1},
        6 => %Job.BonusStats{level: 6, str: 1},
        7 => %Job.BonusStats{level: 6, str: 1},
        8 => %Job.BonusStats{level: 8, dex: 1},
        9 => %Job.BonusStats{level: 8, dex: 1},
        10 => %Job.BonusStats{level: 10, str: 1},
        11 => %Job.BonusStats{level: 11, str: 1},
        12 => %Job.BonusStats{level: 12, agi: 1},
        13 => %Job.BonusStats{level: 12, agi: 1},
        14 => %Job.BonusStats{level: 14, dex: 1},
        15 => %Job.BonusStats{level: 15, luk: 1},
        16 => %Job.BonusStats{level: 15, luk: 1},
        17 => %Job.BonusStats{level: 17, vit: 1},
        18 => %Job.BonusStats{level: 17, vit: 1},
        19 => %Job.BonusStats{level: 19, agi: 1},
        20 => %Job.BonusStats{level: 20, agi: 1},
        21 => %Job.BonusStats{level: 21, dex: 1},
        22 => %Job.BonusStats{level: 21, dex: 1},
        23 => %Job.BonusStats{level: 23, vit: 1},
        24 => %Job.BonusStats{level: 23, vit: 1},
        25 => %Job.BonusStats{level: 23, vit: 1},
        26 => %Job.BonusStats{level: 23, vit: 1},
        27 => %Job.BonusStats{level: 27, dex: 1},
        28 => %Job.BonusStats{level: 27, dex: 1},
        29 => %Job.BonusStats{level: 29, luk: 1},
        30 => %Job.BonusStats{level: 29, luk: 1},
        31 => %Job.BonusStats{level: 31, agi: 1},
        32 => %Job.BonusStats{level: 31, agi: 1},
        33 => %Job.BonusStats{level: 33, dex: 1},
        34 => %Job.BonusStats{level: 34, int: 1},
        35 => %Job.BonusStats{level: 34, int: 1},
        36 => %Job.BonusStats{level: 34, int: 1},
        37 => %Job.BonusStats{level: 34, int: 1},
        38 => %Job.BonusStats{level: 38, dex: 1},
        39 => %Job.BonusStats{level: 39, agi: 1},
        40 => %Job.BonusStats{level: 39, agi: 1},
        41 => %Job.BonusStats{level: 41, int: 1},
        42 => %Job.BonusStats{level: 42, luk: 1},
        43 => %Job.BonusStats{level: 43, dex: 1},
        44 => %Job.BonusStats{level: 44, str: 1},
        45 => %Job.BonusStats{level: 44, str: 1},
        46 => %Job.BonusStats{level: 46, int: 1},
        47 => %Job.BonusStats{level: 47, agi: 1},
        48 => %Job.BonusStats{level: 47, agi: 1},
        49 => %Job.BonusStats{level: 49, dex: 1},
        50 => %Job.BonusStats{level: 49, dex: 1}
      },
      base_aspd: %Job.BaseAspd{fist: 40, dagger: 53, bow: 48, shield: 9},
      hp_factor: 85,
      hp_increase: 0,
      sp_factor: 0,
      sp_increase: 400,
      ap_factor: 0,
      ap_increase: 0,
      max_weight: 27_000,
      max_base_level: 99,
      max_job_level: 50,
      max_stats: nil
    }
  end
end
