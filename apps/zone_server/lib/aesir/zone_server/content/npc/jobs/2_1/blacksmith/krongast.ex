defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Blacksmith.Krongast do
  @moduledoc """
  Awaits a custom sword delivery as part of the Blacksmith job quest.

  ## Behavior

  - Accepts the sword from applicants on the delivery step and hands over a receipt.
  - Announces the delivery to the map and thanks applicants who already delivered.
  - Otherwise frets about the late order.

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
        map: "lighthalzen",
        x: 209,
        y: 80,
        dir: 4,
        sprite: 734,
        name: "Krongast",
        scope: :shared,
        unique_name: "Krongast#BLS"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :BSMITH_Q, 0) == 11 and count_item(ctx, 1119) > 0 -> offer_delivery(ctx)
      get_char_var(ctx, :BSMITH_Q, 0) == 14 -> thank_for_delivery(ctx)
      true -> await_sword(ctx)
    end
  end

  defp offer_delivery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Krongast]")
      |> mes("Ohhhhhh~")
      |> mes("Is it here?")
      |> mes("Very nice.")
      |> mes("Let me take a look.")
      |> next()
      |> mes("[Krongast]")
      |> mes("So you're sure this is the item")
      |> mes("I ordered, right? I wouldn't want it if it's been used.")
      |> next()
      |> select(["Whoops, this one is used!", "It was just made, so it's new."])

    if choice == 1 do
      ctx
      |> mes("[Krongast]")
      |> mes("Hmmmmm!")
      |> mes("Please deliver")
      |> mes("the right sword!")
      |> mes("I've been waiting")
      |> mes("long enough already...")
      |> close()
    else
      deliver_sword(ctx)
    end
  end

  defp deliver_sword(ctx) do
    ctx =
      ctx
      |> mes("[Krongast]")
      |> mes("You double checked?")
      |> mes("Alright then, I'll take it!")
      |> next()
      |> set_char_var(:BSMITH_Q, 14)
      |> delitem(1119, 1)
      |> mes("[Krongast]")
      |> mes("Oh ho...")
      |> mes("This is good.")
      |> mes("Much better than")
      |> mes("what I expected.")
      |> next()
      |> mes("[Krongast]")
      |> mes("With this sword...")
      |> mes(
        "My special moves will be even more powerful! I may even be able to perfect my fast attacking techniques! I love it!"
      )
      |> next()
      |> mes("[Krongast]")
      |> mes("Okay then.")
      |> mes("Let me give")
      |> mes("you a receipt.")
      |> next()
      |> give_item(1073, 1)
      |> mes("[Krongast]")
      |> mes("Here is")
      |> mes("your receipt.")
      |> mes("Thank you for")
      |> mes("your business!")

    ctx
    |> mapannounce("lighthalzen", "#{char_name(ctx, 0)}... Thank you for the delivery.", 1)
    |> close()
  end

  defp thank_for_delivery(ctx) do
    ctx |> mes("[Krongast]") |> mes("Thank you") |> mes("for the delivery.") |> close()
  end

  defp await_sword(ctx) do
    ctx
    |> mes("[Krongast]")
    |> mes("...")
    |> next()
    |> mes("[Krongast]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Krongast]")
    |> mes("When will the sword")
    |> mes("I ordered finally arrive?")
    |> mes("I need to try my ultimate skill, ^2F4F4FFine Edge^000000 with it.")
    |> next()
    |> mes("[Krongast]")
    |> mes("Ahhhhhhh!")
    |> mes("I need to")
    |> mes("have that sword!")
    |> close()
  end
end
