defmodule Aesir.ZoneServer.Gm.Commands.ResetSkill do
  @moduledoc """
  `@resetskill` - refunds the calling GM's learned skills into skill points
  (rAthena `resetskill`). Delivery mirrors `@job`: a `{:reset_skills}` message is
  broadcast on the caller's own `"player:<char_id>"` topic, which the already
  subscribed `PlayerSession` picks up. Broadcasting (rather than calling the
  session directly) avoids a self-call deadlock, since the GM command runs inside
  the session process.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Phoenix.PubSub

  @impl true
  def name, do: "resetskill"

  @impl true
  def required_level, do: 60

  @impl true
  def execute(_args, ctx) do
    PubSub.broadcast(Aesir.PubSub, "player:#{ctx.game_state.character_id}", {:reset_skills})
    {:ok, "Skills reset"}
  end
end
