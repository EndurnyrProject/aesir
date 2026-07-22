defmodule Aesir.ZoneServer.Gm.Commands.JobLevel do
  @moduledoc """
  `@joblevelup <amount>` - adds job levels to the calling GM, clamped to the job's
  max job level. Delivery is `PlayerSession.add_job_level/2` on the caller's
  own session.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @usage "Usage: @joblevelup <amount>"

  @impl true
  def name, do: "joblevelup"

  @impl true
  def required_level, do: 60

  @impl true
  def execute([amount_str], _ctx) do
    case Integer.parse(amount_str) do
      {amount, ""} when amount > 0 ->
        PlayerSession.add_job_level(self(), amount)
        {:ok, "Gained #{amount} job level(s)"}

      _ ->
        {:error, @usage}
    end
  end

  def execute(_args, _ctx), do: {:error, @usage}
end
