defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Blacksmith.Talpiz do
  @moduledoc """
  Awaits a custom Arbalest delivery as part of the Blacksmith job quest.

  ## Behavior

  - Accepts the Arbalest from applicants on the delivery step and hands over a receipt.
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
        map: "payon",
        x: 214,
        y: 79,
        dir: 4,
        sprite: 59,
        name: "Talpiz",
        scope: :shared,
        unique_name: "Talpiz#BLS"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :BSMITH_Q, 0) == 12 and count_item(ctx, 1713) > 0 -> offer_delivery(ctx)
      get_char_var(ctx, :BSMITH_Q, 0) == 14 -> thank_for_delivery(ctx)
      true -> await_arbalest(ctx)
    end
  end

  defp offer_delivery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Talpiz]")
      |> mes("Oh~")
      |> mes("Is it finally here?")
      |> mes("The package I ordered?")
      |> next()
      |> mes("[Talpiz]")
      |> mes(
        "Um, this is what I ordered, right? I don't want an Arbalest that's been used before."
      )
      |> next()
      |> select(["Whoops, this is a used one.", "I'm sure it's new."])

    if choice == 1 do
      ctx
      |> mes("[Talpiz]")
      |> mes("Hmmmm.")
      |> mes("Please hurry")
      |> mes("and bring the")
      |> mes("correct item.")
      |> mes("I've waited too")
      |> mes("long already...")
      |> close()
    else
      deliver_arbalest(ctx)
    end
  end

  defp deliver_arbalest(ctx) do
    ctx =
      ctx
      |> mes("[Talpiz]")
      |> mes("So, you're sure?")
      |> mes("Let me take a look...")
      |> next()
      |> set_char_var(:BSMITH_Q, 14)
      |> delitem(1713, 1)
      |> mes("[Talpiz]")
      |> mes("*wheet whoo*")
      |> mes("Very nice!!")
      |> next()
      |> mes("[Talpiz]")
      |> mes(
        "This is truly a quality made custom item. I love how there is a case for an eye patch! I really reallly love this~"
      )
      |> next()
      |> mes("[Talpiz]")
      |> mes("Thank you!")
      |> mes("For something of this quality,")
      |> mes("I can even sell it for a high price even after I've used it!")
      |> next()
      |> give_item(1073, 1)
      |> mes("[Talpiz]")
      |> mes("Here!")
      |> mes("Please take")
      |> mes("your receipt.")
      |> mes("I really appreciate")
      |> mes("your hard work.")

    ctx
    |> mapannounce(
      "payon",
      "Thanks, #{char_name(ctx, 0)}, you really delivered. Everytime I look at this, I love it even more~",
      1
    )
    |> close()
  end

  defp thank_for_delivery(ctx) do
    ctx
    |> mes("[Talpiz]")
    |> mes("Really,")
    |> mes("I can't say it")
    |> mes("enough. This is")
    |> mes("top quality work~!")
    |> close()
  end

  defp await_arbalest(ctx) do
    ctx
    |> mes("[Talpiz]")
    |> mes("Eh...")
    |> mes("When will my")
    |> mes("order arrive?")
    |> next()
    |> mes("[Talpiz]")
    |> mes("A custom made Arbalest")
    |> mes(
      "with a quality case to hold your eye patches. Only one person can make something like that..."
    )
    |> next()
    |> mes("[Talpiz]")
    |> mes("Ahhhhhh...")
    |> mes("The waiting")
    |> mes("is unbearable!")
    |> close()
  end
end
