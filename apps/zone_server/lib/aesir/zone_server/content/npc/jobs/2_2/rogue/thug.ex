defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Rogue.Thug do
  @moduledoc """
  Grumbles at passers-by and hints at the Rogue Guild's location.

  ## Behavior

  - Chases the player off if they claim to be looking at nothing.
  - Otherwise mutters about collecting money at the Rogue Guild.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_ruins",
        x: 86,
        y: 103,
        dir: 1,
        sprite: 118,
        name: "Thug",
        scope: :shared,
        unique_name: "Thug#rg"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Thug]")
      |> mes("*Sigh...*")
      |> mes("What is life?")
      |> mes("And what use")
      |> mes("is money? ...Damn.")
      |> mes("Damn this worthless life!")
      |> next()
      |> mes("[Thug]")
      |> mes("Hey, kid.")
      |> mes("What the hell")
      |> mes("are you lookin' at?")
      |> next()
      |> select(["Me? N-nothing!'", "........"])

    if choice == 1 do
      ctx
      |> mes("[Thug]")
      |> mes("Then get the")
      |> mes("hell out of my face!")
      |> mes("Didn't you hear me?")
      |> mes("Get lost!")
      |> close()
    else
      ctx
      |> mes("[Thug]")
      |> mes("Hmmm...")
      |> mes(
        "Maybe I'll swing by the ^0000FFRogue Guild^000000 in ^0000FFParos Lighthouse^000000..."
      )
      |> next()
      |> mes("[Thug]")
      |> mes("I needz my money,")
      |> mes("and they best have it...")
      |> close()
    end
  end
end
