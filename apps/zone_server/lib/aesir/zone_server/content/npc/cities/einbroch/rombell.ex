defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Rombell do
  @moduledoc """
  Warns about the Einbroch factory's worsening pollution.

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
        map: "ein_in01",
        x: 36,
        y: 204,
        dir: 3,
        sprite: 851,
        name: "Rombell",
        scope: :shared,
        unique_name: "Rombell#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Rombell]")
    |> mes("It's great that the")
    |> mes("factory is making good")
    |> mes("business and drawing")
    |> mes("in a lot of profit, but I still")
    |> mes("have one major concern.")
    |> next()
    |> mes("[Rombell]")
    |> mes("The amount of pollution")
    |> mes("that this place is causing")
    |> mes("is horrific! We've got these")
    |> mes("machines blowing out toxic")
    |> mes("gas all day long! The air")
    |> mes("can't be safe for very long...")
    |> next()
    |> mes("[Rombell]")
    |> mes("I mean, the air we're")
    |> mes("breathing right now is")
    |> mes("pretty foul and things")
    |> mes("are only going to get")
    |> mes("worse. How can we")
    |> mes("solve this problem?")
    |> close()
  end
end
