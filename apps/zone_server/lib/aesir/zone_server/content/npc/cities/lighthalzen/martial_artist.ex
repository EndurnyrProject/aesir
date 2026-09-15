defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.MartialArtist do
  @moduledoc """
  Shares Martial Artist's remarks with visitors to Lighthalzen.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in02",
        x: 289,
        y: 277,
        dir: 3,
        sprite: 753,
        name: "Martial Artist",
        scope: :shared,
        unique_name: "Martial Artist#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Martial Artist]")
    |> mes("Curses...")
    |> mes("I've come to the")
    |> mes("wrong place to seek")
    |> mes("out a challenge. No")
    |> mes("one here is really all")
    |> mes("that mighty or competitive!")
    |> next()
    |> mes("[Martial Artist]")
    |> mes("This whole city thinks")
    |> mes("it can buy power and safety")
    |> mes("with money. They don't know")
    |> mes("the value of a nice, friendly")
    |> mes("brawl. Hopefully, I'll find a")
    |> mes("rival around here soon...")
    |> close()
  end
end
