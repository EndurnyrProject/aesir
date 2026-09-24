defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Blacksmith.Baisulist do
  @moduledoc """
  Awaits an Arc Wand delivery as part of the Blacksmith job quest.

  ## Behavior

  - Accepts the Arc Wand from applicants on the delivery step and hands over a receipt.
  - Announces the delivery to the map and thanks applicants who already delivered.
  - Otherwise complains about the late order.

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
        map: "geffen",
        x: 46,
        y: 164,
        dir: 1,
        sprite: 69,
        name: "Baisulist",
        scope: :shared,
        unique_name: "Baisulist#BLS"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :BSMITH_Q, 0) == 9 and count_item(ctx, 1610) > 0 -> offer_delivery(ctx)
      get_char_var(ctx, :BSMITH_Q, 0) == 14 -> thank_for_delivery(ctx)
      true -> await_order(ctx)
    end
  end

  defp offer_delivery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Baisulist]")
      |> mes("Oh, hello!")
      |> mes("Have you come")
      |> mes("to deliver my")
      |> mes("Arc Wand?")
      |> next()
      |> mes("[Baisulist]")
      |> mes("You sure this is what I ordered, right? I mean, if it's been used,")
      |> mes("I don't want it.")
      |> next()
      |> select(["Whoops, this is one of the items I use...", "I'm sure! It's brand new!"])

    if choice == 1 do
      ctx
      |> mes("[Baisulist]")
      |> mes("Well...")
      |> mes("I guess I can")
      |> mes("wait a little longer.")
      |> mes("Please hurry with")
      |> mes("my delivery~")
      |> close()
    else
      deliver_arc_wand(ctx)
    end
  end

  defp deliver_arc_wand(ctx) do
    ctx =
      ctx
      |> mes("[Baisulist]")
      |> mes("You're")
      |> mes("absolutely sure?")
      |> set_char_var(:BSMITH_Q, 14)
      |> delitem(1610, 1)
      |> next()
      |> mes("[Baisulist]")
      |> mes(
        "Thank you so much for traveling all the way here. That Geschupenschte, please smack him for me when you meet him for being so late on this order..."
      )
      |> next()
      |> mes("[Baisulist]")
      |> mes("Please wait")
      |> mes("a second, let")
      |> mes("me give you a receipt~")
      |> next()
      |> give_item(1073, 1)
      |> mes("[Baisulist]")
      |> mes("Here it is.")
      |> mes("Thank you so much!")
      |> mes("Oh, and good luck~")

    ctx
    |> mapannounce(
      "geffen",
      "Hey, #{char_name(ctx, 0)}, thank you so much for the delivery~",
      1
    )
    |> close()
  end

  defp thank_for_delivery(ctx) do
    ctx
    |> mes("[Baisulist]")
    |> mes("Thank you")
    |> mes("so much for")
    |> mes("the delivery~")
    |> close()
  end

  defp await_order(ctx) do
    ctx
    |> mes("[Baisulist]")
    |> mes("Oh...")
    |> mes("It's been a while")
    |> mes("since I've been")
    |> mes("to Alberta.")
    |> next()
    |> mes("[Baisulist]")
    |> mes("I ordered something")
    |> mes("from there a while ago,")
    |> mes("but I haven't received")
    |> mes("my delivery...")
    |> next()
    |> mes("[Baisulist]")
    |> mes("I wonder...")
    |> mes("Could the Blacksmith Guild")
    |> mes("be undermanned? I can't think of any other reason for them to be late...")
    |> next()
    |> mes("[Baisulist]")
    |> mes("When will I get")
    |> mes("my special Arc Wand?")
    |> close()
  end
end
