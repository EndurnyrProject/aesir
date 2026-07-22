defmodule Aesir.ZoneServer.Gm.Commands.ResetStat do
  @moduledoc """
  `@resetstat` - resets the calling GM's stat allocation, restoring the classic
  status points and trait points earned for the current base level (rAthena
  `resetstate`). Delivery mirrors `@resetskill`: a `{:progression, {:reset_stats}}`
  message is broadcast on the caller's own `"player:<char_id>"` topic, which the already
  subscribed `PlayerSession` picks up. Broadcasting (rather than calling the
  session directly) avoids a self-call deadlock, since the GM command runs inside
  the session process.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Phoenix.PubSub

  @impl true
  def name, do: "resetstat"

  @impl true
  def required_level, do: 60

  @impl true
  def execute(_args, ctx) do
    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{ctx.game_state.character_id}",
      {:progression, {:reset_stats}}
    )

    {:ok, "Stats reset"}
  end
end
