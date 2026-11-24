defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Decii do
  @moduledoc """
  Decii complains about the lack of privacy in the city.

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
        map: "ein_in01",
        x: 208,
        y: 86,
        dir: 3,
        sprite: 855,
        name: "Decii",
        scope: :shared,
        unique_name: "Decii#ein"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Decii]")
    |> mes("This is so")
    |> mes("frustrating!")
    |> mes("I'm surrounded")
    |> mes("by all these ^FF0000people^000000!")
    |> next()
    |> mes("[Decii]")
    |> mes("There's absolutely")
    |> mes("no privacy in a city")
    |> mes("this crowded! I guess")
    |> mes("I should try to move")
    |> mes("out as soon as I can.")
    |> close()
  end
end
