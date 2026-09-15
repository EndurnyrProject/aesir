defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.RekenberGuardDrew do
  @moduledoc """
  Shares Rekenber Guard Drew's remarks with visitors to Lighthalzen.

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
        x: 162,
        y: 304,
        dir: 7,
        sprite: 868,
        name: "Rekenber Guard Drew",
        scope: :shared,
        unique_name: "Rekenber Guard Drew#li"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Rekenber Guard Drew]")
    |> mes("Dude, check it out~")
    |> mes("Official glossy photos")
    |> mes("of the Kafra Ladies. Now...")
    |> mes("With 20% more garter belts!")
    |> emotion(:delight)
    |> next()
    |> mes("[Rekenber Guard Tan]")
    |> mes("So they're all wearing")
    |> mes("garter belts in these?")
    |> mes("Whoa, that means they")
    |> mes("even got the glasses chick")
    |> mes("to wear 'em too? That's the")
    |> mes("best news I've heard all day!")
    |> emotion(:huk)
    |> next()
    |> mes("[Rekenber Guard Drew]")
    |> mes("Okay man, you know these")
    |> mes("are limited edition collector's")
    |> mes("items, so each one is worth")
    |> mes("300,000 zeny. I mean, I have")
    |> mes("an extra set, but I don't know")
    |> mes("if you'd wanna buy them off--")
    |> next()
    |> mes("[Rekenber Guard Tan]")
    |> mes("I'll take them all.")
    |> mes("Wait, all of them except")
    |> mes("for that young kid. Just the")
    |> mes("idea of having her glamour")
    |> mes("photo around strikes me as...")
    |> mes("Yeah. Yeah, it's no good.")
    |> close()
  end
end
