defmodule Aesir.ZoneServer.Mmo.JobManagement.Jobs.BabyPriest do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.JobManagement.Definition

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Tables

  @impl true
  def job do
    %Job{
      id: 4031,
      name: :baby_priest,
      base_hp: Tables.BasepointsBabyPriest.base_hp(),
      base_sp: Tables.BasepointsBabyPriest.base_sp(),
      base_ap: Tables.BasepointsBabyPriest.base_ap(),
      base_exp: Tables.ExpAlchemist.base_exp(),
      job_exp: Tables.ExpAlchemist.job_exp(),
      bonus_stats: %{
        1 => %Job.BonusStats{level: 1, luk: 1},
        2 => %Job.BonusStats{level: 1, luk: 1},
        3 => %Job.BonusStats{level: 3, luk: 1},
        4 => %Job.BonusStats{level: 4, str: 1},
        5 => %Job.BonusStats{level: 4, str: 1},
        6 => %Job.BonusStats{level: 6, agi: 1},
        7 => %Job.BonusStats{level: 7, vit: 1},
        8 => %Job.BonusStats{level: 8, int: 1},
        9 => %Job.BonusStats{level: 9, int: 1},
        10 => %Job.BonusStats{level: 10, luk: 1},
        11 => %Job.BonusStats{level: 11, str: 1},
        12 => %Job.BonusStats{level: 11, str: 1},
        13 => %Job.BonusStats{level: 11, str: 1},
        14 => %Job.BonusStats{level: 14, vit: 1},
        15 => %Job.BonusStats{level: 14, vit: 1},
        16 => %Job.BonusStats{level: 16, dex: 1},
        17 => %Job.BonusStats{level: 17, str: 1},
        18 => %Job.BonusStats{level: 17, str: 1},
        19 => %Job.BonusStats{level: 17, str: 1},
        20 => %Job.BonusStats{level: 20, dex: 1},
        21 => %Job.BonusStats{level: 21, luk: 1},
        22 => %Job.BonusStats{level: 22, int: 1},
        23 => %Job.BonusStats{level: 22, int: 1},
        24 => %Job.BonusStats{level: 22, int: 1},
        25 => %Job.BonusStats{level: 25, dex: 1},
        26 => %Job.BonusStats{level: 25, dex: 1},
        27 => %Job.BonusStats{level: 27, str: 1},
        28 => %Job.BonusStats{level: 27, str: 1},
        29 => %Job.BonusStats{level: 29, agi: 1},
        30 => %Job.BonusStats{level: 29, agi: 1},
        31 => %Job.BonusStats{level: 31, luk: 1},
        32 => %Job.BonusStats{level: 32, dex: 1},
        33 => %Job.BonusStats{level: 32, dex: 1},
        34 => %Job.BonusStats{level: 34, vit: 1},
        35 => %Job.BonusStats{level: 35, str: 1},
        36 => %Job.BonusStats{level: 36, vit: 1},
        37 => %Job.BonusStats{level: 37, agi: 1},
        38 => %Job.BonusStats{level: 37, agi: 1},
        39 => %Job.BonusStats{level: 39, luk: 1},
        40 => %Job.BonusStats{level: 39, luk: 1},
        41 => %Job.BonusStats{level: 39, luk: 1},
        42 => %Job.BonusStats{level: 42, int: 1},
        43 => %Job.BonusStats{level: 43, int: 1},
        44 => %Job.BonusStats{level: 43, int: 1},
        45 => %Job.BonusStats{level: 45, vit: 1},
        46 => %Job.BonusStats{level: 45, vit: 1},
        47 => %Job.BonusStats{level: 45, vit: 1},
        48 => %Job.BonusStats{level: 48, agi: 1},
        49 => %Job.BonusStats{level: 48, agi: 1},
        50 => %Job.BonusStats{level: 50, luk: 1}
      },
      base_aspd: %Job.BaseAspd{
        fist: 40,
        mace: 43,
        two_handed_mace: 48,
        staff: 60,
        knuckle: 60,
        book: 44,
        two_handed_staff: 60,
        shield: 5
      },
      hp_factor: 75,
      hp_increase: 0,
      sp_factor: 0,
      sp_increase: 800,
      ap_factor: 0,
      ap_increase: 0,
      max_weight: 26_000,
      max_base_level: 99,
      max_job_level: 50,
      max_stats: nil
    }
  end
end
