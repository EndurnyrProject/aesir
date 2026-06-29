defmodule Aesir.ZoneServer.Gm.Commands.Job do
  @moduledoc """
  `@job <job_id | job_name>` - changes the calling GM's job/class. Accepts either
  a numeric job id or a job name (e.g. `knight`). Delivery is the
  `{:change_job, job_id}` cast on the caller's own session.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs

  @usage "Usage: @job <job_id | job_name>"

  @impl true
  def name, do: "job"

  @impl true
  def required_level, do: 60

  @impl true
  def execute([arg], _ctx) do
    with {:ok, job_id, job_name} <- resolve(arg) do
      GenServer.cast(self(), {:change_job, job_id})
      {:ok, "Changed job to #{job_name} (#{job_id})"}
    end
  end

  def execute(_args, _ctx), do: {:error, @usage}

  defp resolve(arg) do
    case Integer.parse(arg) do
      {job_id, ""} -> by_id(job_id)
      _ -> by_name(arg)
    end
  end

  defp by_id(job_id) do
    case AvailableJobs.job_id_to_name(job_id) do
      {:ok, name} -> {:ok, job_id, name}
      {:error, _} -> {:error, "Unknown job"}
    end
  end

  defp by_name(arg) do
    name = arg |> String.downcase() |> String.to_existing_atom()

    case AvailableJobs.job_name_to_id(name) do
      {:ok, job_id} -> {:ok, job_id, name}
      {:error, _} -> {:error, "Unknown job"}
    end
  rescue
    ArgumentError -> {:error, "Unknown job"}
  end
end
