defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Sleik do
  @moduledoc """
  Comments on Einbroch's train station and airship technology.

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
        map: "einbroch",
        x: 229,
        y: 149,
        dir: 3,
        sprite: 854,
        name: "Sleik",
        scope: :shared,
        unique_name: "Sleik#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Sleik]")
    |> mes("Surprisingly, we have")
    |> mes("a Train Station that everyone")
    |> mes("has been calling a victory for")
    |> mes("science. I mean, shouldn't we")
    |> mes("be more amazed by the Airship?")
    |> next()
    |> mes("[Sleik]")
    |> mes("Now, if you want to know")
    |> mes("where the train actually goes,")
    |> mes("I wouldn't be able to tell you.")
    |> mes("After all, I never rode it. But")
    |> mes("still, I guess having our own")
    |> mes("Train Station is a good thing.")
    |> close()
  end
end
