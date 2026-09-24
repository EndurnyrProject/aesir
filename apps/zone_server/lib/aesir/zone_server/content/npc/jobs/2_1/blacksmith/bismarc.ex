defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Blacksmith.Bismarc do
  @moduledoc """
  Awaits a Ring Pommel Saber delivery as part of the Blacksmith job quest.

  ## Behavior

  - Accepts the Ring Pommel Saber from applicants on the delivery step and hands over a receipt.
  - Announces the delivery to the map and thanks applicants who already delivered.
  - Otherwise groans about the poison while waiting for the order.

  ## Credits

  - Original from rAthena, authors and Contributors
    - EREMES THE CANIVALIZER
    - yoshiki
    - Komurka
    - kobra_k88
    - Lupus
    - celest
    - Poki#3
    - Vicious
    - Silent
    - L0ne_W0lf
    - Yommy
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hugel",
        x: 168,
        y: 183,
        dir: 1,
        sprite: 118,
        name: "Bismarc",
        scope: :shared,
        unique_name: "Bismarc#BLS"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :BSMITH_Q, 0) == 13 and count_item(ctx, 1122) > 0 -> offer_delivery(ctx)
      get_char_var(ctx, :BSMITH_Q, 0) == 14 -> thank_for_delivery(ctx)
      true -> await_antidote(ctx)
    end
  end

  defp offer_delivery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Bismarc]")
      |> mes("Sweet God...")
      |> mes("Have you sent")
      |> mes("an angel...?")
      |> mes("Is that the Ring Pommel Saber")
      |> mes("I ordered? It's my only hope...")
      |> next()
      |> mes("[Bismarc]")
      |> mes("^666666*Huuuk*^000000 This is what I ordered, right? I needed one especially")
      |> mes("made to stop this poison...")
      |> next()
      |> select(["Whoops, this is my own Ring Pommel Saber.", "I'm sure this is the one."])

    if choice == 1 do
      ctx
      |> mes("[Bismarc]")
      |> mes("N-Nooo...")
      |> mes("Hurry...!")
      |> mes("I need that")
      |> mes("sword for its")
      |> mes("an...ti...d-dote!")
      |> next()
      |> mes("^3355FFIt looks like")
      |> mes("he's slowly dying...!")
      |> mes("You'd better hurry.^000000")
      |> close()
    else
      deliver_saber(ctx)
    end
  end

  defp deliver_saber(ctx) do
    ctx =
      ctx
      |> mes("[Bismarc]")
      |> mes("^666666*Ghklk*^000000")
      |> mes("Give it...!")
      |> mes("Pleeeease!")
      |> next()
      |> set_char_var(:BSMITH_Q, 14)
      |> delitem(1122, 1)
      |> mes("^3355FFBismarc stabs")
      |> mes("himself, repeatedly,")
      |> mes("with the Ring Pommel Saber")
      |> mes("that has been imbued with")
      |> mes("the power of Green Herbs.^000000")
      |> next()
      |> mes("[Bismarc]")
      |> mes("^666666*Ghyklk*^000000")
      |> mes("*Gasp gasp*")
      |> next()
      |> mes("[Bismarc]")
      |> mes("Please...")
      |> mes("Help me up.")
      |> mes("The poison is")
      |> mes("still coarsing")
      |> mes("through my body...")
      |> next()
      |> mes("[Bismarc]")
      |> mes("OwwwWWWW!!")
      |> mes("IT'S BURNING!")
      |> next()
      |> mes("[Bismarc]")
      |> mes("*Gasp Gasp*")
      |> mes("*Whew* Okay,")
      |> mes("I can feel the")
      |> mes("antidote working now.")
      |> mes("Just what I needed.")
      |> next()
      |> give_item(1073, 1)
      |> mes("[Bismarc]")
      |> mes("Here is")
      |> mes("your receipt.")
      |> mes("T-take it...!")
      |> mes("It's yours!")

    ctx
    |> mapannounce(
      "hugel",
      "Thanks, #{char_name(ctx, 0)}, for the delivery. You saved my life...",
      1
    )
    |> close()
  end

  defp thank_for_delivery(ctx) do
    ctx
    |> mes("[Bismarc]")
    |> mes("Thank you.")
    |> mes("You saved")
    |> mes("my life...")
    |> close()
  end

  defp await_antidote(ctx) do
    ctx
    |> mes("[Bismarc]")
    |> mes("^666666*Ghyklk*^000000")
    |> mes("^666666*Huk Hukk*^000000")
    |> mes("When will my")
    |> mes("o-order arrive...?")
    |> next()
    |> mes("[Bismarc]")
    |> mes("The poison in")
    |> mes("my body... the pain...")
    |> mes("excruciating... L-lord...")
    |> next()
    |> mes("[Bismarc]")
    |> mes("When is the")
    |> mes("antidote gonna")
    |> mes("get here?!")
    |> close()
  end
end
