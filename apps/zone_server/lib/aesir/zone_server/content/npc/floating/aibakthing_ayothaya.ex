defmodule Aesir.ZoneServer.Content.Npc.Floating.AibakthingAyothaya do
  @moduledoc """
  Aibakthing, who tells travelers about Ayothaya and sells the crossing.

  ## Behavior

  - Describes Ayothaya's people, cuisine and the Sa-mhing Tiger legend, or
    offers the trip for 10,000 zeny.
  - A player who accepts and can pay is charged and warped to Ayothaya; one
    short of the fare, or who declines, gets the invitation to dream of the
    country instead.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/ayothaya.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 246,
        y: 29,
        dir: 3,
        sprite: 843,
        name: "Aibakthing",
        scope: :renewal,
        unique_name: "Aibakthing#ayo"
      },
      %{
        map: "alberta",
        x: 247,
        y: 42,
        dir: 3,
        sprite: 843,
        name: "Aibakthing",
        scope: :pre_renewal,
        unique_name: "Aibakthing#ayo"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @fare 10_000

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aibakthing]")
      |> mes("Hoo! Hah! Hoo! Hah!")
      |> mes("Let me take you away to")
      |> mes("a distant spiritual place,")
      |> mes("a land of exotic mystery,")
      |> mes("my hometown Ayothaya!")
      |> next()
      |> select(["About Ayothaya.", "Go to Ayothaya.", "Cancel."])

    case choice do
      1 -> describe_ayothaya(ctx)
      2 -> offer_the_crossing(ctx)
      3 -> dream_of_ayothaya(ctx)
      _ -> ctx
    end
  end

  defp describe_ayothaya(ctx) do
    ctx
    |> mes("[Aibakthing]")
    |> mes(
      "We Ayothayans are a pious people who value peace and sincerity. We endeavor to lead simple, yet noble, lives in harmony with nature."
    )
    |> next()
    |> mes("[Aibakthing]")
    |> mes(
      "Our traditional cuisine is world famous. It's no surprise when we serve dishes like Tom Yum Goong, made of Shrimp, Lemon and Chillies, which has a tantalizing aroma and flavor beyond imagining."
    )
    |> next()
    |> mes("[Aibakthing]")
    |> mes(
      "For those who crave adventure, there is an age old story about the Sa-mhing Tiger, an evil creature that haunts our temple ruins."
    )
    |> next()
    |> mes("[Aibakthing]")
    |> mes("Hoo! Hahh! Hoo! Hahh!")
    |> mes("No man alive can resist the")
    |> mes("call of this beautiful land.")
    |> mes("Midgardians are")
    |> mes("always welcome!")
    |> close()
  end

  defp offer_the_crossing(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Aibakthing]")
      |> mes("Ah, you must pay 10,000 Zeny")
      |> mes("if you wish to visit Ayothaya.")
      |> mes("If you're ready, we can leave")
      |> mes("right now~")
      |> next()
      |> select(["I'm ready, let's go!", "No."])

    if answer == 1 do
      sail(ctx)
    else
      dream_of_ayothaya(ctx)
    end
  end

  defp sail(ctx) do
    if zeny(ctx) > 9_999 do
      ctx
      |> mes("[Aibakthing]")
      |> mes("Hoo! Hah! Hoo! Hah!")
      |> mes("Let us be off! Back to my")
      |> mes("beautiful Ayothaya!")
      |> close()
      |> pay_zeny(@fare)
      |> warp("ayothaya", 149, 71)
    else
      ctx
      |> mes("[Aibakthing]")
      |> mes(
        "I am sorry, but you do not have the 10,000 Zeny to travel to Ayothaya. Such a price is nothing compared to the experiences that await you!"
      )
      |> close()
    end
  end

  defp dream_of_ayothaya(ctx) do
    ctx
    |> mes("[Aibakthing]")
    |> mes("Have you ever dreamed")
    |> mes("of a beautiful place filled")
    |> mes("with spiritual serenity? You")
    |> mes("must have been dreaming")
    |> mes("of Ayothaya, my friend.")
    |> close()
  end
end
