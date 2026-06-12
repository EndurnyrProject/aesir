defmodule Aesir.ZoneServer.Mmo.JobManagement.Jobs.Rogue do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.JobManagement.Definition

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Tables

  @impl true
  def job do
    %Job{
      id: 17,
      name: :rogue,
      base_hp: Tables.BasepointsBabyRogue.base_hp(),
      base_sp: Tables.BasepointsBabyRogue.base_sp(),
      base_ap: Tables.BasepointsBabyRogue.base_ap(),
      base_exp: Tables.ExpAlchemist.base_exp(),
      job_exp: Tables.ExpAlchemist.job_exp(),
      bonus_stats: %{
        1 => %Job.BonusStats{level: 1, agi: 1},
        2 => %Job.BonusStats{level: 2, vit: 1},
        3 => %Job.BonusStats{level: 3, dex: 1},
        4 => %Job.BonusStats{level: 3, dex: 1},
        5 => %Job.BonusStats{level: 5, str: 1},
        6 => %Job.BonusStats{level: 6, vit: 1},
        7 => %Job.BonusStats{level: 7, agi: 1},
        8 => %Job.BonusStats{level: 7, agi: 1},
        9 => %Job.BonusStats{level: 9, vit: 1},
        10 => %Job.BonusStats{level: 9, vit: 1},
        11 => %Job.BonusStats{level: 11, dex: 1},
        12 => %Job.BonusStats{level: 11, dex: 1},
        13 => %Job.BonusStats{level: 11, dex: 1},
        14 => %Job.BonusStats{level: 14, vit: 1},
        15 => %Job.BonusStats{level: 15, vit: 1},
        16 => %Job.BonusStats{level: 16, agi: 1},
        17 => %Job.BonusStats{level: 16, agi: 1},
        18 => %Job.BonusStats{level: 18, dex: 1},
        19 => %Job.BonusStats{level: 18, dex: 1},
        20 => %Job.BonusStats{level: 20, dex: 1},
        21 => %Job.BonusStats{level: 20, dex: 1},
        22 => %Job.BonusStats{level: 20, dex: 1},
        23 => %Job.BonusStats{level: 23, agi: 1},
        24 => %Job.BonusStats{level: 23, agi: 1},
        25 => %Job.BonusStats{level: 25, str: 1},
        26 => %Job.BonusStats{level: 26, vit: 1},
        27 => %Job.BonusStats{level: 27, str: 1},
        28 => %Job.BonusStats{level: 27, str: 1},
        29 => %Job.BonusStats{level: 29, agi: 1},
        30 => %Job.BonusStats{level: 30, str: 1},
        31 => %Job.BonusStats{level: 30, str: 1},
        32 => %Job.BonusStats{level: 30, str: 1},
        33 => %Job.BonusStats{level: 33, dex: 1},
        34 => %Job.BonusStats{level: 34, dex: 1},
        35 => %Job.BonusStats{level: 34, dex: 1},
        36 => %Job.BonusStats{level: 36, str: 1},
        37 => %Job.BonusStats{level: 36, str: 1},
        38 => %Job.BonusStats{level: 38, int: 1},
        39 => %Job.BonusStats{level: 39, agi: 1},
        40 => %Job.BonusStats{level: 39, agi: 1},
        41 => %Job.BonusStats{level: 39, agi: 1},
        42 => %Job.BonusStats{level: 42, str: 1},
        43 => %Job.BonusStats{level: 43, int: 1},
        44 => %Job.BonusStats{level: 43, int: 1},
        45 => %Job.BonusStats{level: 45, agi: 1},
        46 => %Job.BonusStats{level: 45, agi: 1},
        47 => %Job.BonusStats{level: 47, int: 1},
        48 => %Job.BonusStats{level: 48, int: 1},
        49 => %Job.BonusStats{level: 48, int: 1},
        50 => %Job.BonusStats{level: 50, dex: 1}
      },
      base_aspd: %Job.BaseAspd{fist: 40, dagger: 45, one_handed_sword: 50, bow: 50, shield: 5},
      hp_factor: 85,
      hp_increase: 0,
      sp_factor: 0,
      sp_increase: 500,
      ap_factor: 0,
      ap_increase: 0,
      max_weight: 24_000,
      max_base_level: 99,
      max_job_level: 50,
      max_stats: nil
    }
  end
end
