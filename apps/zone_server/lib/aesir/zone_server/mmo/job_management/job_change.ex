defmodule Aesir.ZoneServer.Mmo.JobManagement.JobChange do
  @moduledoc """
  Decoupled, tell-don't-ask public entry point for changing a player's job.

  Validates `job_id`, then broadcasts `{:progression, {:change_job, job_id}}`
  on the player's `"player:<char_id>"` PubSub topic. The caller needs only the
  `char_id`, never
  the session pid; `PlayerSession` (already subscribed to that topic) picks up
  the message and delegates to `ProgressionHandler.apply_job_change/2`.
  """

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Phoenix.PubSub

  @doc """
  Requests a job change for `char_id`. Returns `{:error, :unknown_job}` and
  broadcasts nothing when `job_id` does not resolve to a known job.
  """
  @spec request(char_id :: non_neg_integer(), job_id :: non_neg_integer()) ::
          :ok | {:error, :unknown_job}
  def request(char_id, job_id) do
    case AvailableJobs.job_id_to_name(job_id) do
      {:ok, _job_name} ->
        PubSub.broadcast(Aesir.PubSub, "player:#{char_id}", {:progression, {:change_job, job_id}})

      {:error, :unknown_job_id} ->
        {:error, :unknown_job}
    end
  end
end
