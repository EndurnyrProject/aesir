defmodule Aesir.ZoneServer.Content.Npc.Cities.Geffen.Hadenheim do
  @moduledoc """
  Discusses the Schwarzwald Republic and the growth of foreign trade.

  ## Behavior

  - Explains Schwarzwald to unfamiliar visitors.
  - Tailors his business remarks to Merchants and Novices.

  ## Credits

  - Original from rAthena, authors and Contributors
    - massdriller
    - Nexon
    - MasterOfMuppets
    - Silent
    - Musashiden
    - Evera
    - L0ne_W0lf
    - Lesbian
    - Lupus
    - Samuray22
    - DeadlySilence

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "geffen_in", x: 114, y: 73, dir: 5, sprite: 709, name: "Hadenheim", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hans Hadenheim]")
      |> mes("Man, the Midgard continent sure is big! How's it going, youngster?")
      |> next()
      |> mes("[Hans Hadenheim]")
      |> mes(
        "This Geffen sure is strange. But it was worth it to travel here all the way from the Schwarzwald Republic."
      )
      |> next()
      |> select(["Schwarzwald Republic?", "So, why are you traveling?"])

    if choice == 1 do
      explain_schwarzwald(ctx)
    else
      discuss_business(ctx)
    end
  end

  defp explain_schwarzwald(ctx) do
    ctx
    |> mes("[Hans Hadenheim]")
    |> mes("You...")
    |> mes("Don't know the")
    |> mes("Schwarzwald Republic?")
    |> next()
    |> mes("[Hans Hadenheim]")
    |> mes("You know, ally of the Rune-Midgarts Kingdom. Um... Our capital city is Juno?")
    |> next()
    |> mes("[Hans Hadenheim]")
    |> mes("You should really")
    |> mes("read up on your")
    |> mes("world events!")
    |> close()
  end

  defp discuss_business(ctx) do
    ctx =
      ctx
      |> mes("[Hans Hadenheim]")
      |> mes(
        "Oh, you know, for business. It seems there's a lot of good money in foreign commerce."
      )
      |> next()
      |> mes("[Hans Hadenheim]")
      |> mes(
        "I mean, all these new cities are being discovered by explorers, so import and export trade is really booming!"
      )
      |> next()
      |> mes("[Hans Handenheim]")
      |> address_visitor()

    ctx
    |> next()
    |> mes("[Hans Hadenheim]")
    |> mes(
      "Have you been some of these new lands? They're really interesting and you can learn a lot of new things from these foreign cultures."
    )
    |> next()
    |> mes("[Hans Hadenheim]")
    |> mes(
      "Still, if you want to go sightseeing, I personally recommend that you visit my hometown of Juno. It's quite beautiful, you know."
    )
    |> close()
  end

  defp address_visitor(ctx) do
    cond do
      base_job(ctx) == :merchant ->
        mes(
          ctx,
          "You're in the trading business yourself, right? So of course you'd understand that we're in a Golden Age of trade!"
        )

      class(ctx) == :novice ->
        ctx
        |> mes("I guess...")
        |> mes("Those kinds of concepts might be too high brow for a rookie like you.")

      true ->
        mes(ctx, "Anyway...")
    end
  end
end
