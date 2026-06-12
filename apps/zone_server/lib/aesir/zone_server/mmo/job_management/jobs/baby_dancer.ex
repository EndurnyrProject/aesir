defmodule Aesir.ZoneServer.Mmo.JobManagement.Jobs.BabyDancer do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.JobManagement.Definition

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Tables

  @impl true
  def job do
    %Job{
      id: 4043,
      name: :baby_dancer,
      base_hp: Tables.BasepointsBabyBard.base_hp(),
      base_sp: Tables.BasepointsBabyBard.base_sp(),
      base_ap: Tables.BasepointsBabyBard.base_ap(),
      base_exp: Tables.ExpAlchemist.base_exp(),
      job_exp: Tables.ExpAlchemist.job_exp(),
      bonus_stats: %{
        1 => %Job.BonusStats{level: 1, luk: 1},
        2 => %Job.BonusStats{level: 2, agi: 1},
        3 => %Job.BonusStats{level: 3, str: 1},
        4 => %Job.BonusStats{level: 3, str: 1},
        5 => %Job.BonusStats{level: 5, int: 1},
        6 => %Job.BonusStats{level: 6, dex: 1},
        7 => %Job.BonusStats{level: 7, luk: 1},
        8 => %Job.BonusStats{level: 7, luk: 1},
        9 => %Job.BonusStats{level: 9, dex: 1},
        10 => %Job.BonusStats{level: 10, agi: 1},
        11 => %Job.BonusStats{level: 11, agi: 1},
        12 => %Job.BonusStats{level: 11, agi: 1},
        13 => %Job.BonusStats{level: 13, int: 1},
        14 => %Job.BonusStats{level: 13, int: 1},
        15 => %Job.BonusStats{level: 15, luk: 1},
        16 => %Job.BonusStats{level: 16, dex: 1},
        17 => %Job.BonusStats{level: 17, vit: 1},
        18 => %Job.BonusStats{level: 17, vit: 1},
        19 => %Job.BonusStats{level: 19, luk: 1},
        20 => %Job.BonusStats{level: 20, dex: 1},
        21 => %Job.BonusStats{level: 21, int: 1},
        22 => %Job.BonusStats{level: 21, int: 1},
        23 => %Job.BonusStats{level: 21, int: 1},
        24 => %Job.BonusStats{level: 24, agi: 1},
        25 => %Job.BonusStats{level: 24, agi: 1},
        26 => %Job.BonusStats{level: 24, agi: 1},
        27 => %Job.BonusStats{level: 24, agi: 1},
        28 => %Job.BonusStats{level: 28, str: 1},
        29 => %Job.BonusStats{level: 28, str: 1},
        30 => %Job.BonusStats{level: 30, agi: 1},
        31 => %Job.BonusStats{level: 30, agi: 1},
        32 => %Job.BonusStats{level: 32, luk: 1},
        33 => %Job.BonusStats{level: 33, vit: 1},
        34 => %Job.BonusStats{level: 33, vit: 1},
        35 => %Job.BonusStats{level: 35, agi: 1},
        36 => %Job.BonusStats{level: 35, agi: 1},
        37 => %Job.BonusStats{level: 35, agi: 1},
        38 => %Job.BonusStats{level: 38, luk: 1},
        39 => %Job.BonusStats{level: 38, luk: 1},
        40 => %Job.BonusStats{level: 40, int: 1},
        41 => %Job.BonusStats{level: 41, dex: 1},
        42 => %Job.BonusStats{level: 41, dex: 1},
        43 => %Job.BonusStats{level: 43, vit: 1},
        44 => %Job.BonusStats{level: 43, vit: 1},
        45 => %Job.BonusStats{level: 43, vit: 1},
        46 => %Job.BonusStats{level: 46, luk: 1},
        47 => %Job.BonusStats{level: 47, int: 1},
        48 => %Job.BonusStats{level: 48, agi: 1},
        49 => %Job.BonusStats{level: 48, agi: 1},
        50 => %Job.BonusStats{level: 50, luk: 1}
      },
      base_aspd: %Job.BaseAspd{fist: 40, dagger: 53, bow: 48, whip: 45, shield: 7},
      hp_factor: 75,
      hp_increase: 300,
      sp_factor: 0,
      sp_increase: 600,
      ap_factor: 0,
      ap_increase: 0,
      max_weight: 27_000,
      max_base_level: 99,
      max_job_level: 50,
      max_stats: nil
    }
  end
end
