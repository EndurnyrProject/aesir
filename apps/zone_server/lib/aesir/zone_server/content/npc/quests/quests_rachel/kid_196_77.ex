defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Kid19677 do
  @moduledoc """
  A child wondering when Bruspetti will return from her travels.

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
        map: "rachel",
        x: 196,
        y: 77,
        dir: 3,
        sprite: 921,
        name: "Kid",
        scope: :shared,
        unique_name: "Kid#1rachel"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Kid]")
    |> mes("Hey, have you seen")
    |> mes("Bruspetti? She's really")
    |> mes("nice and always buys me")
    |> mes("lots and lots of cookies!")
    |> next()
    |> mes("[Kid]")
    |> mes("Hmm, I haven't seen")
    |> mes("her in a while, though.")
    |> mes("I heard she went traveling")
    |> mes("somewhere. How long do")
    |> mes("you think she'll be gone, huh?")
    |> close()
  end
end
