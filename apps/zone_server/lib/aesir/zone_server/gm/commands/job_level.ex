defmodule Aesir.ZoneServer.Gm.Commands.JobLevel do
  @moduledoc """
  `@joblevelup <amount>` - adds job levels to the calling GM, clamped to the job's
  max job level. Delivery is the `{:add_job_level, amount}` cast on the caller's
  own session.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  @usage "Usage: @joblevelup <amount>"

  @impl true
  def name, do: "joblevelup"

  @impl true
  def required_level, do: 60

  @impl true
  def execute([amount_str], _ctx) do
    case Integer.parse(amount_str) do
      {amount, ""} when amount > 0 ->
        GenServer.cast(self(), {:add_job_level, amount})
        {:ok, "Gained #{amount} job level(s)"}

      _ ->
        {:error, @usage}
    end
  end

  def execute(_args, _ctx), do: {:error, @usage}
end
