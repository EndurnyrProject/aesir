defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Kid151155 do
  @moduledoc """
  A child dreaming of becoming an adventurer and leaving town.

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
        x: 151,
        y: 155,
        dir: 3,
        sprite: 921,
        name: "Kid",
        scope: :shared,
        unique_name: "Kid#2rachel"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Kid]")
    |> mes("Oh wow! I wanna be an")
    |> mes("adventurer like you when")
    |> mes("I grow up! Go to all sorts")
    |> mes("of places, visit different")
    |> mes("towns. It sounds so fun!")
    |> next()
    |> mes("[Kid]")
    |> mes("Maybe if I find a really")
    |> mes("nice place, maybe I'll just")
    |> mes("stay and then move there.")
    |> mes("There's somewhere here")
    |> mes("that did that, and moved")
    |> mes("from Lighthalzen to here~")
    |> next()
    |> mes("[Kid]")
    |> mes("Yeah, as soon as I get")
    |> mes("a chance, I'm gonna ditch")
    |> mes("this town and see as much")
    |> mes("of the world as I can! I need")
    |> mes("to grow up faster than this!")
    |> close()
  end
end
