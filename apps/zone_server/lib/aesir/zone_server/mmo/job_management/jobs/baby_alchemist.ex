defmodule Aesir.ZoneServer.Mmo.JobManagement.Jobs.BabyAlchemist do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.JobManagement.Definition

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Tables

  @impl true
  def job do
    %Job{
      id: 4041,
      name: :baby_alchemist,
      base_hp: Tables.BasepointsAlchemist.base_hp(),
      base_sp: Tables.BasepointsAlchemist.base_sp(),
      base_ap: Tables.BasepointsAlchemist.base_ap(),
      base_exp: Tables.ExpAlchemist.base_exp(),
      job_exp: Tables.ExpAlchemist.job_exp(),
      bonus_stats: %{
        1 => %Job.BonusStats{level: 1, int: 1},
        2 => %Job.BonusStats{level: 2, dex: 1},
        3 => %Job.BonusStats{level: 3, dex: 1},
        4 => %Job.BonusStats{level: 3, dex: 1},
        5 => %Job.BonusStats{level: 3, dex: 1},
        6 => %Job.BonusStats{level: 6, str: 1},
        7 => %Job.BonusStats{level: 6, str: 1},
        8 => %Job.BonusStats{level: 8, dex: 1},
        9 => %Job.BonusStats{level: 9, int: 1},
        10 => %Job.BonusStats{level: 9, int: 1},
        11 => %Job.BonusStats{level: 11, agi: 1},
        12 => %Job.BonusStats{level: 11, agi: 1},
        13 => %Job.BonusStats{level: 13, dex: 1},
        14 => %Job.BonusStats{level: 14, agi: 1},
        15 => %Job.BonusStats{level: 15, str: 1},
        16 => %Job.BonusStats{level: 15, str: 1},
        17 => %Job.BonusStats{level: 17, int: 1},
        18 => %Job.BonusStats{level: 17, int: 1},
        19 => %Job.BonusStats{level: 19, dex: 1},
        20 => %Job.BonusStats{level: 20, vit: 1},
        21 => %Job.BonusStats{level: 21, dex: 1},
        22 => %Job.BonusStats{level: 21, dex: 1},
        23 => %Job.BonusStats{level: 23, int: 1},
        24 => %Job.BonusStats{level: 24, int: 1},
        25 => %Job.BonusStats{level: 25, dex: 1},
        26 => %Job.BonusStats{level: 26, str: 1},
        27 => %Job.BonusStats{level: 26, str: 1},
        28 => %Job.BonusStats{level: 28, dex: 1},
        29 => %Job.BonusStats{level: 29, int: 1},
        30 => %Job.BonusStats{level: 29, int: 1},
        31 => %Job.BonusStats{level: 31, vit: 1},
        32 => %Job.BonusStats{level: 32, dex: 1},
        33 => %Job.BonusStats{level: 32, dex: 1},
        34 => %Job.BonusStats{level: 34, str: 1},
        35 => %Job.BonusStats{level: 34, str: 1},
        36 => %Job.BonusStats{level: 36, vit: 1},
        37 => %Job.BonusStats{level: 36, vit: 1},
        38 => %Job.BonusStats{level: 38, int: 1},
        39 => %Job.BonusStats{level: 38, int: 1},
        40 => %Job.BonusStats{level: 40, agi: 1},
        41 => %Job.BonusStats{level: 40, agi: 1},
        42 => %Job.BonusStats{level: 40, agi: 1},
        43 => %Job.BonusStats{level: 43, str: 1},
        44 => %Job.BonusStats{level: 43, str: 1},
        45 => %Job.BonusStats{level: 45, agi: 1},
        46 => %Job.BonusStats{level: 45, agi: 1},
        47 => %Job.BonusStats{level: 45, agi: 1},
        48 => %Job.BonusStats{level: 45, agi: 1},
        49 => %Job.BonusStats{level: 49, agi: 1},
        50 => %Job.BonusStats{level: 50, agi: 1}
      },
      base_aspd: %Job.BaseAspd{
        fist: 40,
        dagger: 50,
        one_handed_sword: 45,
        one_handed_axe: 45,
        two_handed_axe: 52,
        mace: 45,
        two_handed_mace: 50,
        shield: 4
      },
      hp_factor: 90,
      hp_increase: 0,
      sp_factor: 0,
      sp_increase: 400,
      ap_factor: 0,
      ap_increase: 0,
      max_weight: 30_000,
      max_base_level: 99,
      max_job_level: 50,
      max_stats: nil
    }
  end
end
