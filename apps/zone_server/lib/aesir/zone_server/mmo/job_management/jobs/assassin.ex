defmodule Aesir.ZoneServer.Mmo.JobManagement.Jobs.Assassin do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.JobManagement.Definition

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Tables

  @impl true
  def job do
    %Job{
      id: 12,
      name: :assassin,
      base_hp: Tables.BasepointsAssassin.base_hp(),
      base_sp: Tables.BasepointsAssassin.base_sp(),
      base_ap: Tables.BasepointsAssassin.base_ap(),
      base_exp: Tables.ExpAlchemist.base_exp(),
      job_exp: Tables.ExpAlchemist.job_exp(),
      bonus_stats: %{
        1 => %Job.BonusStats{level: 1, agi: 1},
        2 => %Job.BonusStats{level: 2, agi: 1},
        3 => %Job.BonusStats{level: 3, agi: 1},
        4 => %Job.BonusStats{level: 4, int: 1},
        5 => %Job.BonusStats{level: 4, int: 1},
        6 => %Job.BonusStats{level: 6, vit: 1},
        7 => %Job.BonusStats{level: 6, vit: 1},
        8 => %Job.BonusStats{level: 8, vit: 1},
        9 => %Job.BonusStats{level: 9, dex: 1},
        10 => %Job.BonusStats{level: 9, dex: 1},
        11 => %Job.BonusStats{level: 11, str: 1},
        12 => %Job.BonusStats{level: 11, str: 1},
        13 => %Job.BonusStats{level: 11, str: 1},
        14 => %Job.BonusStats{level: 14, int: 1},
        15 => %Job.BonusStats{level: 15, agi: 1},
        16 => %Job.BonusStats{level: 16, agi: 1},
        17 => %Job.BonusStats{level: 17, agi: 1},
        18 => %Job.BonusStats{level: 18, agi: 1},
        19 => %Job.BonusStats{level: 19, agi: 1},
        20 => %Job.BonusStats{level: 20, agi: 1},
        21 => %Job.BonusStats{level: 21, agi: 1},
        22 => %Job.BonusStats{level: 21, agi: 1},
        23 => %Job.BonusStats{level: 21, agi: 1},
        24 => %Job.BonusStats{level: 24, dex: 1},
        25 => %Job.BonusStats{level: 25, str: 1},
        26 => %Job.BonusStats{level: 25, str: 1},
        27 => %Job.BonusStats{level: 27, str: 1},
        28 => %Job.BonusStats{level: 27, str: 1},
        29 => %Job.BonusStats{level: 27, str: 1},
        30 => %Job.BonusStats{level: 30, dex: 1},
        31 => %Job.BonusStats{level: 31, dex: 1},
        32 => %Job.BonusStats{level: 32, str: 1},
        33 => %Job.BonusStats{level: 32, str: 1},
        34 => %Job.BonusStats{level: 32, str: 1},
        35 => %Job.BonusStats{level: 32, str: 1},
        36 => %Job.BonusStats{level: 32, str: 1},
        37 => %Job.BonusStats{level: 32, str: 1},
        38 => %Job.BonusStats{level: 38, int: 1},
        39 => %Job.BonusStats{level: 38, int: 1},
        40 => %Job.BonusStats{level: 40, dex: 1},
        41 => %Job.BonusStats{level: 41, dex: 1},
        42 => %Job.BonusStats{level: 42, int: 1},
        43 => %Job.BonusStats{level: 42, int: 1},
        44 => %Job.BonusStats{level: 42, int: 1},
        45 => %Job.BonusStats{level: 45, str: 1},
        46 => %Job.BonusStats{level: 46, dex: 1},
        47 => %Job.BonusStats{level: 46, dex: 1},
        48 => %Job.BonusStats{level: 48, str: 1},
        49 => %Job.BonusStats{level: 48, str: 1},
        50 => %Job.BonusStats{level: 50, dex: 1}
      },
      base_aspd: %Job.BaseAspd{
        fist: 40,
        dagger: 42,
        one_handed_sword: 50,
        one_handed_axe: 51,
        katar: 42,
        huuma: 110,
        shield: 6
      },
      hp_factor: 110,
      hp_increase: 0,
      sp_factor: 0,
      sp_increase: 400,
      ap_factor: 0,
      ap_increase: 0,
      max_weight: 24_000,
      max_base_level: 99,
      max_job_level: 50,
      max_stats: nil
    }
  end
end
