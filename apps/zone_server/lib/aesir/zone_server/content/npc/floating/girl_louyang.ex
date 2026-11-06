defmodule Aesir.ZoneServer.Content.Npc.Floating.GirlLouyang do
  @moduledoc """
  Girl in Alberta who tells travelers about Luoyang and guides them there.

  ## Behavior

  - Describes Luoyang's history, its beasts and its martial artists, or offers
    to guide the player there for 10,000 zeny.
  - Charges the fee and warps to the Luoyang fields; a player short of zeny, or
    who declines, gets a parting line instead.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/louyang.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 246,
        y: 40,
        dir: 3,
        sprite: 815,
        name: "Girl",
        scope: :renewal,
        unique_name: "Girl#0lou"
      },
      %{
        map: "alberta",
        x: 245,
        y: 45,
        dir: 3,
        sprite: 815,
        name: "Girl",
        scope: :pre_renewal,
        unique_name: "Girl#0lou"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @fare 10_000

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Girl]")
      |> mes("La la la la~")
      |> mes("I feel so good today~")
      |> mes("I'm in the mood to go")
      |> mes("on a picnic somewhere~")
      |> mes("La la la la~")
      |> next()
      |> select(["About Luoyang.", "Go to Luoyang.", "Cancel."])

    case choice do
      1 -> describe_luoyang(ctx)
      2 -> offer_the_guided_trip(ctx)
      3 -> ctx |> mes("[Girl]") |> mes("Oh...") |> mes("Have a good day!") |> close()
      _ -> ctx
    end
  end

  defp describe_luoyang(ctx) do
    ctx
    |> mes("[Girl]")
    |> mes("Oh, are you")
    |> mes("interested in Luoyang?")
    |> mes("It's a nice place to")
    |> mes("visit for travelers.")
    |> next()
    |> mes("[Girl]")
    |> mes("Luoyang has a long history")
    |> mes(
      "with stories of ancient magic and warriors. It's also rumored that many evil beasts roam the"
    )
    |> mes("Luoyang area.")
    |> next()
    |> mes("[Girl]")
    |> mes("You can find cure-all medicines, mysterious occurrences, and")
    |> mes("martial artists all in one place!")
    |> next()
    |> mes("[Girl]")
    |> mes(
      "I used to train in the martial arts every morning back when I was in Luoyang. I might not look like it, but I'm pretty strong!"
    )
    |> next()
    |> mes("[Girl]")
    |> mes("If you want to visit")
    |> mes("Luoyang, feel free to")
    |> mes("tell me. Just give me")
    |> mes("some Zeny and we'll go~")
    |> close()
  end

  defp offer_the_guided_trip(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Girl]")
      |> mes("I'll guide you to")
      |> mes("Luoyang right away.")
      |> mes("For my service, I am")
      |> mes("accepting 10,000 Zeny.")
      |> next()
      |> mes("[Girl]")
      |> mes("So, are you ready?")
      |> next()
      |> select(["Yes!", "No."])

    if answer == 1 do
      guide(ctx)
    else
      ctx
      |> mes("[Girl]")
      |> mes("Oh...")
      |> mes("It's so disappointing")
      |> mes("to hear you say that.")
      |> mes("Well, have a good day!")
      |> close()
    end
  end

  defp guide(ctx) do
    if zeny(ctx) > 9_999 do
      ctx
      |> mes("[Girl]")
      |> mes("Okay~")
      |> mes("Ready!")
      |> mes("Have fun!")
      |> close()
      |> pay_zeny(@fare)
      |> warp("lou_fild01", 190, 101)
    else
      ctx
      |> mes("[Girl]")
      |> mes("...")
      |> mes("You don't seem")
      |> mes("to have 10,000 Zeny...")
      |> mes("Go get some money first!")
      |> close()
    end
  end
end
