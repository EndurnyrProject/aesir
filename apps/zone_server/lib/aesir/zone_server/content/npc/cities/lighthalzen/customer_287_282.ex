defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Customer287282 do
  @moduledoc """
  Shows Greenfield rationalizing his repeated losses at Dice.

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
        x: 287,
        y: 282,
        dir: 4,
        sprite: 853,
        name: "Customer",
        scope: :shared,
        unique_name: "Customer#amano10"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Greenfield]")
    |> mes("I don't believe it...")
    |> mes("This unlucky streak")
    |> mes("will never end, will it?")
    |> mes("I lost all my Apples")
    |> mes("playing Dice today.")
    |> mes("Again. Oh man...")
    |> next()
    |> mes("[Greenfield]")
    |> mes("Okay. Okay.")
    |> mes("If I just keep")
    |> mes("playing, eventually")
    |> mes("I'll win. I mean, that's")
    |> mes("the way the odds work, right?")
    |> mes("Even when they're against me...")
    |> close()
  end
end
