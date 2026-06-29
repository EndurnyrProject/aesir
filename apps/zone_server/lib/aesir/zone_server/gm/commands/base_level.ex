defmodule Aesir.ZoneServer.Gm.Commands.BaseLevel do
  @moduledoc """
  `@baselevelup <amount>` - adds base levels to the calling GM, clamped to the
  job's max base level. Delivery is the `{:add_base_level, amount}` cast on the
  caller's own session.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  @usage "Usage: @baselevelup <amount>"

  @impl true
  def name, do: "baselevelup"

  @impl true
  def required_level, do: 60

  @impl true
  def execute([amount_str], _ctx) do
    case Integer.parse(amount_str) do
      {amount, ""} when amount > 0 ->
        GenServer.cast(self(), {:add_base_level, amount})
        {:ok, "Gained #{amount} base level(s)"}

      _ ->
        {:error, @usage}
    end
  end

  def execute(_args, _ctx), do: {:error, @usage}
end
