defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Tsuen do
  @moduledoc """
  Reflects on factory management and his abandoned dream of adventuring.

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
        x: 84,
        y: 218,
        dir: 3,
        sprite: 851,
        name: "Tsuen",
        scope: :shared,
        unique_name: "Tsuen#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Tsuen]")
    |> mes("There was a time")
    |> mes("when I dreamed of")
    |> mes("being an adventurer,")
    |> mes("just like you. But that")
    |> mes("was a long time ago...")
    |> next()
    |> mes("[Tsuen]")
    |> mes("Now, I'm nothing but")
    |> mes("a factory manager. Still,")
    |> mes("even if my job's not that")
    |> mes("great, I'm pretty satisfied.")
    |> mes("I'm sure people enjoy the")
    |> mes("products I oversee and all...")
    |> next()
    |> mes("[Tsuen]")
    |> mes("Maybe my life was meant")
    |> mes("to be this way, even if it's")
    |> mes("not how I planned it. But the")
    |> mes("time will come when I up and")
    |> mes("leave and travel the world")
    |> mes("once I get my chance!")
    |> next()
    |> mes("[Tsuen]")
    |> mes("I hope the day will")
    |> mes("come when I can meet")
    |> mes("you out in that big wide")
    |> mes("world and greet you as")
    |> mes("a fellow adventurer.")
    |> close()
  end
end
