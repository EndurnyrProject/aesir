defmodule Aesir.ZoneServer.Mmo.JobManagement.Jobs.BabySage do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.JobManagement.Definition

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Tables

  @impl true
  def job do
    %Job{
      id: 4039,
      name: :baby_sage,
      base_hp: Tables.BasepointsBabySage.base_hp(),
      base_sp: Tables.BasepointsBabySage.base_sp(),
      base_ap: Tables.BasepointsBabySage.base_ap(),
      base_exp: Tables.ExpAlchemist.base_exp(),
      job_exp: Tables.ExpAlchemist.job_exp(),
      bonus_stats: %{
        1 => %Job.BonusStats{level: 1, int: 1},
        2 => %Job.BonusStats{level: 1, int: 1},
        3 => %Job.BonusStats{level: 3, agi: 1},
        4 => %Job.BonusStats{level: 4, vit: 1},
        5 => %Job.BonusStats{level: 4, vit: 1},
        6 => %Job.BonusStats{level: 6, agi: 1},
        7 => %Job.BonusStats{level: 6, agi: 1},
        8 => %Job.BonusStats{level: 8, int: 1},
        9 => %Job.BonusStats{level: 8, int: 1},
        10 => %Job.BonusStats{level: 8, int: 1},
        11 => %Job.BonusStats{level: 11, vit: 1},
        12 => %Job.BonusStats{level: 11, vit: 1},
        13 => %Job.BonusStats{level: 13, agi: 1},
        14 => %Job.BonusStats{level: 13, agi: 1},
        15 => %Job.BonusStats{level: 15, int: 1},
        16 => %Job.BonusStats{level: 15, int: 1},
        17 => %Job.BonusStats{level: 17, luk: 1},
        18 => %Job.BonusStats{level: 18, vit: 1},
        19 => %Job.BonusStats{level: 18, vit: 1},
        20 => %Job.BonusStats{level: 20, dex: 1},
        21 => %Job.BonusStats{level: 20, dex: 1},
        22 => %Job.BonusStats{level: 22, agi: 1},
        23 => %Job.BonusStats{level: 22, agi: 1},
        24 => %Job.BonusStats{level: 24, int: 1},
        25 => %Job.BonusStats{level: 25, dex: 1},
        26 => %Job.BonusStats{level: 25, dex: 1},
        27 => %Job.BonusStats{level: 27, dex: 1},
        28 => %Job.BonusStats{level: 27, dex: 1},
        29 => %Job.BonusStats{level: 27, dex: 1},
        30 => %Job.BonusStats{level: 30, int: 1},
        31 => %Job.BonusStats{level: 30, int: 1},
        32 => %Job.BonusStats{level: 32, dex: 1},
        33 => %Job.BonusStats{level: 33, agi: 1},
        34 => %Job.BonusStats{level: 33, agi: 1},
        35 => %Job.BonusStats{level: 35, luk: 1},
        36 => %Job.BonusStats{level: 35, luk: 1},
        37 => %Job.BonusStats{level: 37, int: 1},
        38 => %Job.BonusStats{level: 38, int: 1},
        39 => %Job.BonusStats{level: 39, dex: 1},
        40 => %Job.BonusStats{level: 40, luk: 1},
        41 => %Job.BonusStats{level: 40, luk: 1},
        42 => %Job.BonusStats{level: 42, str: 1},
        43 => %Job.BonusStats{level: 42, str: 1},
        44 => %Job.BonusStats{level: 44, str: 1},
        45 => %Job.BonusStats{level: 45, int: 1},
        46 => %Job.BonusStats{level: 46, str: 1},
        47 => %Job.BonusStats{level: 47, str: 1},
        48 => %Job.BonusStats{level: 48, str: 1},
        49 => %Job.BonusStats{level: 48, str: 1},
        50 => %Job.BonusStats{level: 50, int: 1}
      },
      base_aspd: %Job.BaseAspd{
        fist: 45,
        dagger: 53,
        one_handed_sword: 60,
        staff: 55,
        book: 43,
        two_handed_staff: 55,
        shield: 5
      },
      hp_factor: 75,
      hp_increase: 0,
      sp_factor: 0,
      sp_increase: 700,
      ap_factor: 0,
      ap_increase: 0,
      max_weight: 24_000,
      max_base_level: 99,
      max_job_level: 50,
      max_stats: nil
    }
  end
end
