defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.MaleFollower do
  @moduledoc """
  Male followers greet visitors to the pope’s chamber.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_temsky",
        x: 93,
        y: 97,
        dir: 6,
        sprite: 926,
        name: "Male Follower",
        scope: :shared,
        unique_name: "ramale",
        hidden_name: "1rachel"
      },
      %{
        map: "ra_temsky",
        x: 90,
        y: 95,
        dir: 6,
        sprite: 926,
        name: "Male Follower",
        scope: :shared,
        unique_name: "Male Follower#2rachel"
      },
      %{
        map: "ra_temsky",
        x: 98,
        y: 59,
        dir: 6,
        sprite: 926,
        name: "Male Follower",
        scope: :shared,
        unique_name: "Male Follower#3rachel"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx |> mes("[Male Follower]") |> mes("May Freya be with you.") |> close()
  end
end
