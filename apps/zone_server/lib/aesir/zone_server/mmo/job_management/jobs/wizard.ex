defmodule Aesir.ZoneServer.Mmo.JobManagement.Jobs.Wizard do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.JobManagement.Definition

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Tables

  @impl true
  def job do
    %Job{
      id: 9,
      name: :wizard,
      base_hp: Tables.BasepointsBabyWizard.base_hp(),
      base_sp: Tables.BasepointsBabyWizard.base_sp(),
      base_ap: Tables.BasepointsBabyWizard.base_ap(),
      base_exp: Tables.ExpAlchemist.base_exp(),
      job_exp: Tables.ExpAlchemist.job_exp(),
      bonus_stats: %{
        1 => %Job.BonusStats{level: 1, int: 1},
        2 => %Job.BonusStats{level: 2, dex: 1},
        3 => %Job.BonusStats{level: 2, dex: 1},
        4 => %Job.BonusStats{level: 4, int: 1},
        5 => %Job.BonusStats{level: 5, dex: 1},
        6 => %Job.BonusStats{level: 6, agi: 1},
        7 => %Job.BonusStats{level: 6, agi: 1},
        8 => %Job.BonusStats{level: 6, agi: 1},
        9 => %Job.BonusStats{level: 9, int: 1},
        10 => %Job.BonusStats{level: 10, agi: 1},
        11 => %Job.BonusStats{level: 10, agi: 1},
        12 => %Job.BonusStats{level: 12, str: 1},
        13 => %Job.BonusStats{level: 13, dex: 1},
        14 => %Job.BonusStats{level: 13, dex: 1},
        15 => %Job.BonusStats{level: 15, luk: 1},
        16 => %Job.BonusStats{level: 15, luk: 1},
        17 => %Job.BonusStats{level: 15, luk: 1},
        18 => %Job.BonusStats{level: 18, int: 1},
        19 => %Job.BonusStats{level: 18, int: 1},
        20 => %Job.BonusStats{level: 18, int: 1},
        21 => %Job.BonusStats{level: 18, int: 1},
        22 => %Job.BonusStats{level: 22, int: 1},
        23 => %Job.BonusStats{level: 22, int: 1},
        24 => %Job.BonusStats{level: 24, agi: 1},
        25 => %Job.BonusStats{level: 24, agi: 1},
        26 => %Job.BonusStats{level: 26, dex: 1},
        27 => %Job.BonusStats{level: 26, dex: 1},
        28 => %Job.BonusStats{level: 26, dex: 1},
        29 => %Job.BonusStats{level: 29, int: 1},
        30 => %Job.BonusStats{level: 29, int: 1},
        31 => %Job.BonusStats{level: 31, int: 1},
        32 => %Job.BonusStats{level: 32, dex: 1},
        33 => %Job.BonusStats{level: 33, int: 1},
        34 => %Job.BonusStats{level: 34, agi: 1},
        35 => %Job.BonusStats{level: 34, agi: 1},
        36 => %Job.BonusStats{level: 36, luk: 1},
        37 => %Job.BonusStats{level: 36, luk: 1},
        38 => %Job.BonusStats{level: 38, vit: 1},
        39 => %Job.BonusStats{level: 39, dex: 1},
        40 => %Job.BonusStats{level: 40, int: 1},
        41 => %Job.BonusStats{level: 41, agi: 1},
        42 => %Job.BonusStats{level: 41, agi: 1},
        43 => %Job.BonusStats{level: 43, agi: 1},
        44 => %Job.BonusStats{level: 43, agi: 1},
        45 => %Job.BonusStats{level: 45, int: 1},
        46 => %Job.BonusStats{level: 46, agi: 1},
        47 => %Job.BonusStats{level: 47, agi: 1},
        48 => %Job.BonusStats{level: 48, int: 1},
        49 => %Job.BonusStats{level: 48, int: 1},
        50 => %Job.BonusStats{level: 50, int: 1}
      },
      base_aspd: %Job.BaseAspd{fist: 50, dagger: 54, staff: 53, two_handed_staff: 53, shield: 8},
      hp_factor: 55,
      hp_increase: 0,
      sp_factor: 0,
      sp_increase: 900,
      ap_factor: 0,
      ap_increase: 0,
      max_weight: 24_000,
      max_base_level: 99,
      max_job_level: 50,
      max_stats: nil
    }
  end
end
