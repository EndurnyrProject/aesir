defmodule Aesir.ZoneServer.Gm.Commands.GiveAllSkills do
  @moduledoc """
  `@giveallskills` - maximizes the calling GM's current job-lineage skills.
  Sends a progression event to the GM's own session to avoid a self-call.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Phoenix.PubSub

  @impl true
  def name, do: "giveallskills"

  @impl true
  def required_level, do: 60

  @impl true
  def execute(_args, ctx) do
    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{ctx.game_state.character_id}",
      {:progression, {:give_all_skills}}
    )

    {:ok, "Skills maximized"}
  end
end
