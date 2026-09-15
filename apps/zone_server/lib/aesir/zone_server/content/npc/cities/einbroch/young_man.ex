defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.YoungMan do
  @moduledoc """
  Explains his work acquiring and delivering exotic goods.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - reddozen
    - Komurka
    - erKURITA
    - RockmanEXE
    - Dj-Yhn
    - Silent
    - Evera
    - Samuray22
    - DZeroX
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "airport",
        x: 174,
        y: 41,
        dir: 6,
        sprite: 99,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#air"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Runnan]")
    |> mes("...And that's why")
    |> mes("I travel around the")
    |> mes("globe. My bosses have")
    |> mes("a keen eye for the most")
    |> mes("exotic goods, so I acquire")
    |> mes("them and make deliveries.")
    |> next()
    |> mes("[Runnan]")
    |> mes("There even was a time")
    |> mes("when they had me collect")
    |> mes("Jellopy, though that stuff is")
    |> mes("pretty common nowadays.")
    |> mes("Now that I think about it, why")
    |> mes("did they need so much stuff?")
    |> close()
  end
end
