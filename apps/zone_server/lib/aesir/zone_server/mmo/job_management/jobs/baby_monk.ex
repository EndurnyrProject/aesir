defmodule Aesir.ZoneServer.Mmo.JobManagement.Jobs.BabyMonk do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.JobManagement.Definition

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Tables

  @impl true
  def job do
    %Job{
      id: 4038,
      name: :baby_monk,
      base_hp: Tables.BasepointsBabyMonk.base_hp(),
      base_sp: Tables.BasepointsBabyMonk.base_sp(),
      base_ap: Tables.BasepointsBabyMonk.base_ap(),
      base_exp: Tables.ExpAlchemist.base_exp(),
      job_exp: Tables.ExpAlchemist.job_exp(),
      bonus_stats: %{
        1 => %Job.BonusStats{level: 1, str: 1},
        2 => %Job.BonusStats{level: 2, str: 1},
        3 => %Job.BonusStats{level: 2, str: 1},
        4 => %Job.BonusStats{level: 4, dex: 1},
        5 => %Job.BonusStats{level: 5, agi: 1},
        6 => %Job.BonusStats{level: 5, agi: 1},
        7 => %Job.BonusStats{level: 7, vit: 1},
        8 => %Job.BonusStats{level: 7, vit: 1},
        9 => %Job.BonusStats{level: 7, vit: 1},
        10 => %Job.BonusStats{level: 10, agi: 1},
        11 => %Job.BonusStats{level: 10, agi: 1},
        12 => %Job.BonusStats{level: 12, str: 1},
        13 => %Job.BonusStats{level: 13, str: 1},
        14 => %Job.BonusStats{level: 13, str: 1},
        15 => %Job.BonusStats{level: 15, luk: 1},
        16 => %Job.BonusStats{level: 16, int: 1},
        17 => %Job.BonusStats{level: 16, int: 1},
        18 => %Job.BonusStats{level: 18, agi: 1},
        19 => %Job.BonusStats{level: 18, agi: 1},
        20 => %Job.BonusStats{level: 20, vit: 1},
        21 => %Job.BonusStats{level: 21, agi: 1},
        22 => %Job.BonusStats{level: 22, dex: 1},
        23 => %Job.BonusStats{level: 23, agi: 1},
        24 => %Job.BonusStats{level: 23, agi: 1},
        25 => %Job.BonusStats{level: 25, vit: 1},
        26 => %Job.BonusStats{level: 26, str: 1},
        27 => %Job.BonusStats{level: 27, str: 1},
        28 => %Job.BonusStats{level: 27, str: 1},
        29 => %Job.BonusStats{level: 27, str: 1},
        30 => %Job.BonusStats{level: 30, dex: 1},
        31 => %Job.BonusStats{level: 30, dex: 1},
        32 => %Job.BonusStats{level: 32, luk: 1},
        33 => %Job.BonusStats{level: 33, vit: 1},
        34 => %Job.BonusStats{level: 33, vit: 1},
        35 => %Job.BonusStats{level: 35, agi: 1},
        36 => %Job.BonusStats{level: 35, agi: 1},
        37 => %Job.BonusStats{level: 35, agi: 1},
        38 => %Job.BonusStats{level: 38, int: 1},
        39 => %Job.BonusStats{level: 38, int: 1},
        40 => %Job.BonusStats{level: 40, luk: 1},
        41 => %Job.BonusStats{level: 41, vit: 1},
        42 => %Job.BonusStats{level: 41, vit: 1},
        43 => %Job.BonusStats{level: 43, dex: 1},
        44 => %Job.BonusStats{level: 44, agi: 1},
        45 => %Job.BonusStats{level: 44, agi: 1},
        46 => %Job.BonusStats{level: 46, vit: 1},
        47 => %Job.BonusStats{level: 46, vit: 1},
        48 => %Job.BonusStats{level: 46, vit: 1},
        49 => %Job.BonusStats{level: 49, str: 1},
        50 => %Job.BonusStats{level: 50, str: 1}
      },
      base_aspd: %Job.BaseAspd{
        fist: 40,
        mace: 43,
        two_handed_mace: 48,
        staff: 60,
        knuckle: 40,
        two_handed_staff: 58,
        shield: 5
      },
      hp_factor: 90,
      hp_increase: 650,
      sp_factor: 0,
      sp_increase: 470,
      ap_factor: 0,
      ap_increase: 0,
      max_weight: 26_000,
      max_base_level: 99,
      max_job_level: 50,
      max_stats: nil
    }
  end
end
