defmodule Aesir.ZoneServer.Mmo.Mechanics.StatCost.Renewal do
  @moduledoc """
  Renewal status-point costs and parameter caps.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.StatCost

  alias Aesir.ZoneServer.Mmo.JobManagement.TraitJobs

  @impl true
  @spec cost_to_raise(non_neg_integer()) :: pos_integer()
  def cost_to_raise(value) when value < 100, do: 2 + div(value - 1, 10)
  def cost_to_raise(value), do: 16 + 4 * div(value - 100, 5)

  @impl true
  @spec max_parameter(non_neg_integer()) :: pos_integer()
  def max_parameter(job_id) do
    if TraitJobs.trait_job?(job_id), do: 135, else: 99
  end

  @impl true
  @spec max_trait_parameter(non_neg_integer()) :: non_neg_integer()
  def max_trait_parameter(job_id) do
    if TraitJobs.trait_job?(job_id), do: 100, else: 0
  end
end
