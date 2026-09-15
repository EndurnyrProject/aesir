defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Wallace do
  @moduledoc """
  Shares Wallace's remarks with visitors to Lighthalzen.

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
        x: 202,
        y: 94,
        dir: 5,
        sprite: 847,
        name: "Wallace",
        scope: :shared,
        unique_name: "Wallace#zen2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Wallace]")
    |> mes("......")
    |> mes("That lady, working")
    |> mes("for that one company,")
    |> mes("Kafra, Mafra or whatever.")
    |> mes("She certainly is very charming.")
    |> next()
    |> mes("[Wallace]")
    |> mes("Now, if I were")
    |> mes("thirty years younger...")
    |> mes("Wait! I'm a rich and powerful")
    |> mes("man. I could ask her out now.")
    |> mes("Hm? What's that look for?")
    |> close()
  end
end
