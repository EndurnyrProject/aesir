defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.YoungMan54251 do
  @moduledoc """
  A drunken traveler reacts to Satan Morocc’s revival and the city’s destruction.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc",
        x: 54,
        y: 251,
        dir: 0,
        sprite: 89,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#moc02"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Drunken Young Man]")
    |> mes("Wait a second..! Are you perhaps an adventurer? Welcome! How's your trip?")
    |> mes(
      "Heh heh~ Let me tell you a story. You know I just got out of that Tavern, there, huh?"
    )
    |> next()
    |> mes("[Drunken Young Man]")
    |> mes(
      "I heard the Satan Morocc has revived. It just got out of cracking the time and the space blar... hic~"
    )
    |> next()
    |> mes("[Drunken Young Man]")
    |> mes(
      "Ah... I kinda wanna see that Satan with my own eyes, but! I really shouldn't. I shouldn't even dream of seeing that Satan in person."
    )
    |> next()
    |> mes("[Drunken Young Man]")
    |> mes(
      "But I think there'd be nothing to lose if you, a person of bravery, who came through the wile desert try to find it, don't you think? Teehee~ Don't forget to buy me a drink when you find it!"
    )
    |> mes("Hic!")
    |> next()
    |> mes("[Drunken Young Man]")
    |> mes(
      "Anyway, do you know where we are? I just had a little drink at a tavern, but all of a sudden, the whole town's disappeared when I got out.. or, some five hundred years have passed???!"
    )
    |> close()
  end
end
