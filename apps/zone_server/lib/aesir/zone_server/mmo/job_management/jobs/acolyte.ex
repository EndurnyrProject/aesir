defmodule Aesir.ZoneServer.Mmo.JobManagement.Jobs.Acolyte do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.JobManagement.Definition

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Tables

  @impl true
  def job do
    %Job{
      id: 4,
      name: :acolyte,
      base_hp: Tables.BasepointsAcolyte.base_hp(),
      base_sp: Tables.BasepointsAcolyte.base_sp(),
      base_ap: Tables.BasepointsAcolyte.base_ap(),
      base_exp: Tables.ExpAcolyte.base_exp(),
      job_exp: Tables.ExpAcolyte.job_exp(),
      bonus_stats: %{
        2 => %Job.BonusStats{level: 2, luk: 1},
        3 => %Job.BonusStats{level: 2, luk: 1},
        4 => %Job.BonusStats{level: 2, luk: 1},
        5 => %Job.BonusStats{level: 2, luk: 1},
        6 => %Job.BonusStats{level: 6, vit: 1},
        7 => %Job.BonusStats{level: 6, vit: 1},
        8 => %Job.BonusStats{level: 6, vit: 1},
        9 => %Job.BonusStats{level: 6, vit: 1},
        10 => %Job.BonusStats{level: 10, int: 1},
        11 => %Job.BonusStats{level: 10, int: 1},
        12 => %Job.BonusStats{level: 10, int: 1},
        13 => %Job.BonusStats{level: 10, int: 1},
        14 => %Job.BonusStats{level: 14, dex: 1},
        15 => %Job.BonusStats{level: 14, dex: 1},
        16 => %Job.BonusStats{level: 14, dex: 1},
        17 => %Job.BonusStats{level: 14, dex: 1},
        18 => %Job.BonusStats{level: 18, luk: 1},
        19 => %Job.BonusStats{level: 18, luk: 1},
        20 => %Job.BonusStats{level: 18, luk: 1},
        21 => %Job.BonusStats{level: 18, luk: 1},
        22 => %Job.BonusStats{level: 22, agi: 1},
        23 => %Job.BonusStats{level: 22, agi: 1},
        24 => %Job.BonusStats{level: 22, agi: 1},
        25 => %Job.BonusStats{level: 22, agi: 1},
        26 => %Job.BonusStats{level: 26, str: 1},
        27 => %Job.BonusStats{level: 26, str: 1},
        28 => %Job.BonusStats{level: 26, str: 1},
        29 => %Job.BonusStats{level: 26, str: 1},
        30 => %Job.BonusStats{level: 30, vit: 1},
        31 => %Job.BonusStats{level: 30, vit: 1},
        32 => %Job.BonusStats{level: 30, vit: 1},
        33 => %Job.BonusStats{level: 33, int: 1},
        34 => %Job.BonusStats{level: 33, int: 1},
        35 => %Job.BonusStats{level: 33, int: 1},
        36 => %Job.BonusStats{level: 36, dex: 1},
        37 => %Job.BonusStats{level: 36, dex: 1},
        38 => %Job.BonusStats{level: 38, luk: 1},
        39 => %Job.BonusStats{level: 38, luk: 1},
        40 => %Job.BonusStats{level: 40, agi: 1},
        41 => %Job.BonusStats{level: 40, agi: 1},
        42 => %Job.BonusStats{level: 42, str: 1},
        43 => %Job.BonusStats{level: 42, str: 1},
        44 => %Job.BonusStats{level: 44, vit: 1},
        45 => %Job.BonusStats{level: 44, vit: 1},
        46 => %Job.BonusStats{level: 46, int: 1},
        47 => %Job.BonusStats{level: 47, dex: 1},
        48 => %Job.BonusStats{level: 47, dex: 1},
        49 => %Job.BonusStats{level: 49, str: 1},
        50 => %Job.BonusStats{level: 50, luk: 1}
      },
      base_aspd: %Job.BaseAspd{
        fist: 40,
        mace: 45,
        two_handed_mace: 50,
        staff: 60,
        two_handed_staff: 60,
        shield: 7
      },
      hp_factor: 40,
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
