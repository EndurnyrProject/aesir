defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.YoungMan do
  @moduledoc """
  A young man talks about the troubled old man behind the pub.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbech",
        x: 57,
        y: 210,
        dir: 3,
        sprite: 855,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#Shinokas_Quest"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Young Man]")
    |> mes("Behind the pub,")
    |> mes("you'll see this old man")
    |> mes("who's always mumbling")
    |> mes("something to himself.")
    |> next()
    |> mes("[Young Man]")
    |> mes("Sometimes he seems really")
    |> mes("angry, but other times he looks")
    |> mes("awfully depressed. He must have")
    |> mes(
      "lived through some really horrible experience. I can't help but feel really sorry for the old guy."
    )
    |> next()
    |> mes("[Young Man]")
    |> mes("He says and does")
    |> mes("a lot of strange things.")
    |> mes("It's sad to see someone")
    |> mes("that old act that way, but")
    |> mes("it makes me wonder what")
    |> mes("could have happened to him.")
    |> close()
  end
end
