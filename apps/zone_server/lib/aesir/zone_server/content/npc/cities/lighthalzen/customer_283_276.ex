defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Customer283276 do
  @moduledoc """
  Shares Sei's thoughts about a shy admirer based on the player's sex.

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
        x: 283,
        y: 276,
        dir: 4,
        sprite: 815,
        name: "Customer",
        scope: :shared,
        unique_name: "Customer#amano12"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Sei]")
      |> mes("You see that guy?")
      |> mes("That guy over there is")
      |> mes("always looking at me.")
      |> mes("I wonder... Does he want")
      |> mes("to ask me out or something?")
      |> next()
      |> mes("[Sei]")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        ctx
        |> mes("Well, if he does,")
        |> mes("shouldn't he have")
        |> mes("more guts? Or are ")
        |> mes("you boys much more")
        |> mes("shy than I think you are?")
      else
        ctx
        |> mes("Well, he is sort of")
        |> mes("cute. Geez, this would")
        |> mes("be so much easier if he")
        |> mes("would just come up and")
        |> mes("start talking to me...")
      end

    close(ctx)
  end
end
