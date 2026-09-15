defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.CityGirl do
  @moduledoc """
  Describes Lanko's tiring work as a waitress and wish to explore the city.

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
        map: "lhz_in03",
        x: 192,
        y: 93,
        dir: 3,
        sprite: 862,
        name: "City Girl",
        scope: :shared,
        unique_name: "City Girl#amano05"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Lanko]")
    |> mes("Oh, I'm only here")
    |> mes("working as a waitress")
    |> mes("to help out my father.")
    |> mes("This job is so tiring, but")
    |> mes("it's nice to see people so")
    |> mes("relaxed and having a good time.")
    |> next()
    |> mes("[Lanko]")
    |> mes("When I get some time")
    |> mes("off, I'm going to explore")
    |> mes("Lighthalzen and see all that")
    |> mes("there is to see. But for now,")
    |> mes("it doesn't look like we've got")
    |> mes("any real shortage of drunks...")
    |> close()
  end
end
