defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Ellette do
  @moduledoc """
  Shows Ellette surprising her coworkers with exceptional productivity.

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
        map: "lhz_in01",
        x: 124,
        y: 28,
        dir: 3,
        sprite: 66,
        name: "Ellette",
        scope: :shared,
        unique_name: "Ellette#tre"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = ctx |> mes("[Ellette]") |> mes("...") |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Excuse me.")
      |> next()
      |> mes("[Ellette]")
      |> mes("...")
      |> mes("......")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Hello?")
    |> next()
    |> mes("[Ellette]")
    |> mes("...Oh! Everyone!")
    |> mes("I just completed")
    |> mes("another one! Hooray!")
    |> next()
    |> mes("[All other Employees]")
    |> mes("Wh-what?!")
    |> mes("No way, not again!")
    |> next()
    |> mes("[Leekal]")
    |> mes("Are you even human?")
    |> mes("You must have some")
    |> mes("secret for that much")
    |> mes("productivity. It's weird...")
    |> next()
    |> mes("[Ellette]")
    |> mes("Oh, come on.")
    |> mes("Maybe I'm a little")
    |> mes("good at this, but there's")
    |> mes("no way I can beat Cenku.")
    |> close()
  end
end
