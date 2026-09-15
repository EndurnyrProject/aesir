defmodule Aesir.ZoneServer.Content.Npc.Cities.Hugel.APartTimer do
  @moduledoc """
  Introduces Luda and the Shrine Expedition Office.

  ## Credits

  - Original from rAthena, authors and Contributors
    - vicious_pucca
    - Poki#3
    - erKURITA
    - Munin

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_in01",
        x: 18,
        y: 94,
        dir: 0,
        sprite: 49,
        name: "A Part-Timer",
        scope: :shared,
        unique_name: "A Part-Timer#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Luda]")
    |> mes("Welcome to the")
    |> mes("Shrine Expedition Office.")
    |> mes("I'm Luda, a part-time")
    |> mes("assistant. My job is to")
    |> mes("keep this office neat and")
    |> mes("clean, but look at this place!")
    |> next()
    |> mes("[Luda]")
    |> mes("Still, I think I can")
    |> mes("handle this difficult task~")
    |> mes("This room is the office for")
    |> mes("the Schwarzwald Republic team,")
    |> mes("and the other is for the Rune-")
    |> mes("Midgarts Kingdom team.")
    |> next()
    |> mes("[Luda]")
    |> mes("I have to clean both rooms,")
    |> mes("so they keep me pretty busy.")
    |> mes("Why don't you volunteer for")
    |> mes("their expedition? I know they")
    |> mes("can't really pay you, but it's")
    |> mes("a great chance to explore~")
    |> close()
  end
end
