defmodule Aesir.ZoneServer.Mmo.JobManagement.Jobs.SkyEmperor2 do
  @moduledoc false
  use Aesir.ZoneServer.Mmo.JobManagement.Definition

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Tables

  @impl true
  def job do
    %Job{
      id: 4316,
      name: :sky_emperor2,
      base_hp: Tables.BasepointsSkyEmperor.base_hp(),
      base_sp: Tables.BasepointsSkyEmperor.base_sp(),
      base_ap: Tables.BasepointsSkyEmperor.base_ap(),
      base_exp: %{},
      job_exp: %{},
      bonus_stats: %{},
      base_aspd: nil,
      hp_factor: 0,
      hp_increase: 0,
      sp_factor: 0,
      sp_increase: 0,
      ap_factor: 0,
      ap_increase: 0,
      max_weight: 0,
      max_base_level: 99,
      max_job_level: 99,
      max_stats: nil
    }
  end
end
