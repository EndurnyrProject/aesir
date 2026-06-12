defmodule Aesir.ZoneServer.Mmo.JobManagement.Jobs.MageHigh do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.JobManagement.Definition

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Tables

  @impl true
  def job do
    %Job{
      id: 4003,
      name: :mage_high,
      base_hp: Tables.BasepointsBabyMage.base_hp(),
      base_sp: Tables.BasepointsBabyMage.base_sp(),
      base_ap: Tables.BasepointsBabyMage.base_ap(),
      base_exp: Tables.ExpAcolyteHigh.base_exp(),
      job_exp: Tables.ExpAcolyteHigh.job_exp(),
      bonus_stats: %{
        2 => %Job.BonusStats{level: 2, int: 1},
        3 => %Job.BonusStats{level: 2, int: 1},
        4 => %Job.BonusStats{level: 2, int: 1},
        5 => %Job.BonusStats{level: 2, int: 1},
        6 => %Job.BonusStats{level: 6, dex: 1},
        7 => %Job.BonusStats{level: 6, dex: 1},
        8 => %Job.BonusStats{level: 6, dex: 1},
        9 => %Job.BonusStats{level: 6, dex: 1},
        10 => %Job.BonusStats{level: 10, dex: 1},
        11 => %Job.BonusStats{level: 10, dex: 1},
        12 => %Job.BonusStats{level: 10, dex: 1},
        13 => %Job.BonusStats{level: 10, dex: 1},
        14 => %Job.BonusStats{level: 14, int: 1},
        15 => %Job.BonusStats{level: 14, int: 1},
        16 => %Job.BonusStats{level: 14, int: 1},
        17 => %Job.BonusStats{level: 14, int: 1},
        18 => %Job.BonusStats{level: 18, agi: 1},
        19 => %Job.BonusStats{level: 18, agi: 1},
        20 => %Job.BonusStats{level: 18, agi: 1},
        21 => %Job.BonusStats{level: 18, agi: 1},
        22 => %Job.BonusStats{level: 22, int: 1},
        23 => %Job.BonusStats{level: 22, int: 1},
        24 => %Job.BonusStats{level: 22, int: 1},
        25 => %Job.BonusStats{level: 22, int: 1},
        26 => %Job.BonusStats{level: 26, agi: 1},
        27 => %Job.BonusStats{level: 26, agi: 1},
        28 => %Job.BonusStats{level: 26, agi: 1},
        29 => %Job.BonusStats{level: 26, agi: 1},
        30 => %Job.BonusStats{level: 30, luk: 1},
        31 => %Job.BonusStats{level: 30, luk: 1},
        32 => %Job.BonusStats{level: 30, luk: 1},
        33 => %Job.BonusStats{level: 33, int: 1},
        34 => %Job.BonusStats{level: 33, int: 1},
        35 => %Job.BonusStats{level: 33, int: 1},
        36 => %Job.BonusStats{level: 36, dex: 1},
        37 => %Job.BonusStats{level: 36, dex: 1},
        38 => %Job.BonusStats{level: 38, int: 1},
        39 => %Job.BonusStats{level: 38, int: 1},
        40 => %Job.BonusStats{level: 40, agi: 1},
        41 => %Job.BonusStats{level: 40, agi: 1},
        42 => %Job.BonusStats{level: 42, luk: 1},
        43 => %Job.BonusStats{level: 42, luk: 1},
        44 => %Job.BonusStats{level: 44, int: 1},
        45 => %Job.BonusStats{level: 44, int: 1},
        46 => %Job.BonusStats{level: 46, int: 1},
        47 => %Job.BonusStats{level: 47, agi: 1},
        48 => %Job.BonusStats{level: 47, agi: 1},
        49 => %Job.BonusStats{level: 49, luk: 1},
        50 => %Job.BonusStats{level: 50, int: 1}
      },
      base_aspd: %Job.BaseAspd{fist: 50, dagger: 50, staff: 55, two_handed_staff: 55, shield: 10},
      hp_factor: 30,
      hp_increase: 0,
      sp_factor: 0,
      sp_increase: 600,
      ap_factor: 0,
      ap_increase: 0,
      max_weight: 22_000,
      max_base_level: 99,
      max_job_level: 50,
      max_stats: nil
    }
  end
end
