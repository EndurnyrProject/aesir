defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Millette do
  @moduledoc """
  Shares Millette's remarks with visitors to Lighthalzen.

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
        x: 153,
        y: 206,
        dir: 4,
        sprite: 853,
        name: "Millette",
        scope: :shared,
        unique_name: "Millette#05"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Millette]")
    |> mes("Let me go!")
    |> mes("Let me GO!!")
    |> mes("LET ME GO!!!")
    |> mes("I didn't do nuthin'")
    |> mes("wrong! I'm innocent!")
    |> mes("^333333*Hic-Hic-Hiccup...*^000000")
    |> next()
    |> mes("[Millette]")
    |> mes("What's wrong with")
    |> mes("drinking and singing")
    |> mes("in the street, huh?")
    |> mes("Is it a crime to have")
    |> mes("a beautiful tenor voice?!")
    |> mes("Get me outta this joint!")
    |> close()
  end
end
