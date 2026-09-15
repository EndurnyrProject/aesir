defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Oyoung do
  @moduledoc """
  Shares Oyoung's remarks with visitors to Lighthalzen.

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
        map: "lighthalzen",
        x: 259,
        y: 108,
        dir: 7,
        sprite: 869,
        name: "Oyoung",
        scope: :shared,
        unique_name: "Oyoung#zen14"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Oyoung]")
      |> mes("Girl, you look like")
      |> mes("you're comin' down with")
      |> mes("the love bug. But there's")
      |> mes("only one prescription for")
      |> mes("this ailment, ooooh yeah...")
      |> next()
      |> mes("[Oyoung]")
      |> mes("You need yo'self")
      |> mes("your daily dose of")
      |> mes("vitamin O-YOUNG.")
      |> mes("And your lips look like")
      |> mes("they got vitamin deficiency.")
      |> mes("I better take care of that~")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Sweet Sister!")
    |> mes("I don't know what's")
    |> mes("more mind boggling--")
    |> mes("The fact that he used")
    |> mes("that line or the fact that")
    |> mes("it's actually working...")
    |> close()
  end
end
