defmodule Aesir.ZoneServer.Mmo.JobManagement.Jobs.Baby do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.JobManagement.Definition

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Tables

  @impl true
  def job do
    %Job{
      id: 4023,
      name: :baby,
      base_hp: Tables.BasepointsBaby.base_hp(),
      base_sp: Tables.BasepointsBaby.base_sp(),
      base_ap: Tables.BasepointsBaby.base_ap(),
      base_exp: Tables.ExpBaby.base_exp(),
      job_exp: Tables.ExpBaby.job_exp(),
      bonus_stats: %{},
      base_aspd: %Job.BaseAspd{
        fist: 40,
        dagger: 55,
        one_handed_sword: 57,
        one_handed_axe: 50,
        mace: 50,
        two_handed_mace: 55,
        staff: 65,
        two_handed_staff: 65,
        shield: 10
      },
      hp_factor: 0,
      hp_increase: 0,
      sp_factor: 0,
      sp_increase: 0,
      ap_factor: 0,
      ap_increase: 0,
      max_weight: 0,
      max_base_level: 99,
      max_job_level: 10,
      max_stats: nil
    }
  end
end
