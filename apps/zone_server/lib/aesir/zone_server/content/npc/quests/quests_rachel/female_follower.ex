defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.FemaleFollower do
  @moduledoc """
  Female followers greet visitors to the pope’s chamber.

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
        x: 106,
        y: 97,
        dir: 4,
        sprite: 916,
        name: "Female Follower",
        scope: :shared,
        unique_name: "rafemale",
        hidden_name: "1rachel"
      },
      %{
        map: "ra_temsky",
        x: 108,
        y: 95,
        dir: 4,
        sprite: 916,
        name: "Female Follower",
        scope: :shared,
        unique_name: "Female Follower#2rachel"
      },
      %{
        map: "ra_temsky",
        x: 101,
        y: 59,
        dir: 4,
        sprite: 916,
        name: "Female Follower",
        scope: :shared,
        unique_name: "Female Follower#3rachel"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx |> mes("[Female Follower]") |> mes("May Freya be with you.") |> close()
  end
end
