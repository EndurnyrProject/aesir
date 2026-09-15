defmodule Aesir.ZoneServer.Content.Npc.Cities.Geffen.SuspiciousGuy do
  @moduledoc """
  Sells suspiciously overpriced Potions, Daggers, and Hoods to nearby visitors.

  ## Behavior

  - Opens his sales pitch when a visitor enters the surrounding area.
  - Sells up to 100 Red Potions, Main Gauches, or Hoods after checking zeny.
  - Repeats quantity prompts above 100 and ends the interaction when zero is entered.

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
      %{
        map: "geffen",
        x: 146,
        y: 148,
        dir: 4,
        sprite: 99,
        name: "Suspicious Guy",
        scope: :shared,
        trigger: {6, 6}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    ctx =
      ctx
      |> mes("[?]")
      |> mes("^333333*Psssst!*")
      |> mes("H-Hey you!")
      |> mes("You wanna get your hands on some great stuff? Come on over!^000000")
      |> next()
      |> mes("[Suspicious Guy]")
      |> greet_visitor()

    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes(
        "So just tell me what you want, and I'll cut you a deal from amongst my valuable, yet affordable, wares."
      )
      |> next()
      |> select([
        "Gimme some potion so I can recover HP.",
        "Um, you got a Knife?",
        "Don't you have a good Manteau?",
        "Don't you have something besides this?"
      ])

    case offer_product(ctx, choice) do
      {:complete, ctx} -> finish_sale(ctx)
      {:stop, ctx} -> ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp greet_visitor(ctx) do
    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
      mes(
        ctx,
        "Hey there tough guy. You look smart enough to recognize a bargain when it's right in front of your eyes."
      )
    else
      mes(
        ctx,
        "Well, well, well. Aren't you a pretty girl. Today just happens to be your lucky day!"
      )
    end
  end

  defp offer_product(ctx, 1), do: offer_red_potions(ctx)
  defp offer_product(ctx, 2), do: offer_main_gauches(ctx)
  defp offer_product(ctx, 3), do: offer_hoods(ctx)

  defp offer_product(ctx, 4) do
    ctx =
      ctx
      |> mes("[Suspicious Guy]")
      |> mes("Man...")
      |> mes(
        "You sure like to ask for the impossible. Well, let me tell you right now. No other Merchant in the world sells the goods only I can offer."
      )
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes("You just gotta believe me!")
      |> close()

    {:stop, ctx}
  end

  defp offer_product(ctx, _choice), do: {:complete, ctx}

  defp offer_red_potions(ctx) do
    {ctx, _choice} =
      ctx
      |> mes("[Suspicious Guy]")
      |> mes("Ah, you into Potions, eh?")
      |> mes("Yeah, I got the stuff!")
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes(
        "Here it is! High quality Red Potion! It starts working right away once you take it. Once it hits your lips, you can't stop. This stuff is that good."
      )
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes(
        "C'mon dude. This is the latest Red Potion. I got it from a close friend of a friend, you know, a real dependable source, and it's real cheap too. You can't pass this up!"
      )
      |> next()
      |> select(["Uh, can I buy White Potions instead?"])

    ctx =
      ctx
      |> mes("[Suspicious Guy]")
      |> mes(
        "White Potions? Oh, those don't exist. But, er, if someone's selling that kind of stuff, bring it to me so I can, um, test the difference. But yeah, I got the real stuff."
      )
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes(
        "You can heal all your wounds by drinking Red Potions! And I'll sell you one for just ^FF3333500 zeny^000000!"
      )
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes(
        "Now, how cheap is that?! Since they're in such high demand, I can only sell you 100 of"
      )
      |> mes("them at a time.")
      |> next()

    case ask_red_potion_amount(ctx) do
      {:cancel, ctx} -> {:stop, ctx}
      {:amount, ctx, amount} -> buy_product(ctx, amount, 500, 501, &red_potion_shortfall/1)
    end
  end

  defp offer_main_gauches(ctx) do
    ctx = mes(ctx, "[Suspicious Guy]")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        ctx
        |> mes(
          "What would a strong guy like you want a knife for? Those will just break under the force of your incredibly powerful swings!"
        )
        |> next()
        |> mes("[Suspicious Guy]")
        |> mes("Now...")
        |> mes("What you really")
        |> mes("need is a ^FF3333manly Dagger^000000.")
      else
        ctx
        |> mes(
          "A nice lady like you? Come on now, kitchen knives are for old naggy wives and the hired help."
        )
        |> next()
        |> mes("[Suspicious Guy]")
        |> mes("Now...")
        |> mes("What you really")
        |> mes("need is a fine, exquisite")
        |> mes("^FF3333French Dagger^000000 to match your beauty and elegance.")
      end

    {ctx, _choice} =
      ctx
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes("I call it...")
      |> mes(
        "The ^FF3333Main Gauche^000000! I invented it myself. And I'm only selling it for 9,400 zeny!"
      )
      |> next()
      |> select(["Aren't you going to give me a sheath too?"])

    ctx =
      ctx
      |> mes("[Suspicious Guy]")
      |> mes("A sheath?")
      |> mes("Whoa, that's almost asking too much! Alright, alright...")
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes(
        "Since I like you so much, I'm giving you a free sheath with your purchase! Now how's that"
      )
      |> mes("for a bargain?")
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes("There's no way you can pass this up! Now, how many do you want?")
      |> next()

    case ask_main_gauche_amount(ctx) do
      {:cancel, ctx} -> {:stop, ctx}
      {:amount, ctx, amount} -> buy_product(ctx, amount, 9400, 1207, &main_gauche_shortfall/1)
    end
  end

  defp offer_hoods(ctx) do
    ctx = mes(ctx, "[Suspicious Guy]")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        mes(ctx, "A Manteau? That's old news! You know what's the latest in protective armors?")
      else
        mes(
          ctx,
          "Now why would such a beautiful woman wear something out of style? You know what would make you look even better?"
        )
      end

    {ctx, _choice} =
      ctx
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes("That's right!")
      |> mes("A Hood! Wearing one of those is the quickest way to win respect these days!")
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes(
        "If you've got a Hood on, monsters will fear you and run away in terror! And check out this sturdy fabric. I can pull it all I want and it won't tear!"
      )
      |> next()
      |> select(["This hood has no drawstrings...? "])

    ctx =
      ctx
      |> mes("[Suspicious Guy]")
      |> mes(
        "Haha! What are you saying? You don't need drawstrings! The space age Rayon and Nylon and Krypton fibers keep the Hood secure on your head!"
      )
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes("Man...")
      |> mes(
        "So much technology was invested into this Hood. Can you believe I'm only selling it for 930 zeny?"
      )
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes("Clearly, this is the deal of the century. So how many do you want?")
      |> next()

    case ask_hood_amount(ctx) do
      {:cancel, ctx} -> {:stop, ctx}
      {:amount, ctx, amount} -> buy_product(ctx, amount, 930, 2501, &hood_shortfall/1)
    end
  end

  defp ask_red_potion_amount(ctx) do
    {ctx, amount} = input(ctx, :int)

    cond do
      amount == 0 -> {:cancel, cancel_red_potions(ctx)}
      amount > 100 -> ask_red_potion_amount(reject_red_potion_amount(ctx))
      true -> {:amount, ctx, amount}
    end
  end

  defp ask_main_gauche_amount(ctx) do
    {ctx, amount} = input(ctx, :int)

    cond do
      amount == 0 -> {:cancel, cancel_main_gauches(ctx)}
      amount > 100 -> ask_main_gauche_amount(reject_main_gauche_amount(ctx))
      true -> {:amount, ctx, amount}
    end
  end

  defp ask_hood_amount(ctx) do
    {ctx, amount} = input(ctx, :int)

    cond do
      amount == 0 -> {:cancel, cancel_hoods(ctx)}
      amount > 100 -> ask_hood_amount(reject_hood_amount(ctx))
      true -> {:amount, ctx, amount}
    end
  end

  defp buy_product(ctx, amount, unit_price, item_id, shortfall_dialogue) do
    price = amount * unit_price

    if zeny(ctx) < price do
      {:stop, shortfall_dialogue.(ctx)}
    else
      ctx = ctx |> pay_zeny(price) |> give_item(item_id, amount)
      {:complete, ctx}
    end
  end

  defp cancel_red_potions(ctx) do
    ctx = mes(ctx, "[Suspicious Guy]")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        mes(
          ctx,
          "Ah duuuuuude~ You're breakin' my heart! I mean, at these prices, I'm practically performing charity!"
        )
      else
        mes(
          ctx,
          "W-waaaait! You didn't let me tell you the part about how Red Potions help you lose and gain weight in all the right places! Waaaaait!"
        )
      end

    close(ctx)
  end

  defp reject_red_potion_amount(ctx) do
    ctx
    |> mes("[Suspicious Guy]")
    |> mes("Whoa...")
    |> mes(
      "I can't let you buy that many. I mean, it's not like, you know, there's a trace impurity in these Potions or anything like that..."
    )
    |> next()
  end

  defp cancel_main_gauches(ctx) do
    ctx
    |> mes("[Suspicious Guy]")
    |> mes(
      "Man, how many chances of a lifetime have you passed up? Man, I hope you win the lottery..."
    )
    |> mes("You'd probably")
    |> mes("pass that up too.")
    |> close()
  end

  defp reject_main_gauche_amount(ctx) do
    ctx
    |> mes("[Suspicious Guy]")
    |> mes("Whoa!")
    |> mes(
      "I can't sell that many Daggers! That'll attract the Prontera Chiv--I mean, um, I was gonna donate some Daggers to... Hungry children?"
    )
    |> next()
  end

  defp cancel_hoods(ctx) do
    ctx
    |> mes("[Suspicious Guy]")
    |> mes("Awww...")
    |> mes("It wasn't because of the whole drawstrings thing, was it?")
    |> close()
  end

  defp reject_hood_amount(ctx) do
    ctx
    |> mes("[Suspicious Guy]")
    |> mes("Whoa~!")
    |> mes("I can't sell you that many! What are you trying to do, take advantage of me?")
    |> next()
  end

  defp red_potion_shortfall(ctx) do
    ctx
    |> mes("[Suspicious Guy]")
    |> mes("Oh maaan~")
    |> mes("Are you")
    |> mes("short on dough?")
    |> mes("That's no good.")
    |> next()
    |> mes("[Suspicious Guy]")
    |> mes(
      "^333333Now I gotta find some other sucker to dump this junk on!^000000 *Ahem* I mean, come again!"
    )
    |> close()
  end

  defp main_gauche_shortfall(ctx) do
    ctx
    |> mes("[Suspicious Guy]")
    |> mes("Short on zeny?")
    |> mes(
      "When the greatest deal in your life is right before your eyes?! Tragic, truly tragic..."
    )
    |> close()
  end

  defp hood_shortfall(ctx) do
    ctx
    |> mes("[Suspicious Guy]")
    |> mes("Oh nuts...")
    |> mes("Short on zeny, eh?")
    |> close()
  end

  defp finish_sale(ctx) do
    ctx
    |> mes("[Suspicious Guy]")
    |> mes("No need to look anywhere else at all when I clearly have the best items around!")
    |> next()
    |> mes("[Suspicious Guy]")
    |> mes(
      "Please come back sometime, and buy more of my stuff. I love a customer who knows what they want! Hehe~"
    )
    |> close()
  end
end
