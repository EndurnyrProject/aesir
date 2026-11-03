defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMerchant.Guarnien do
  @moduledoc """
  Guarnien, the Merchant Guild lecturer who walks new Merchants through the basics of trading.

  ## Behavior

  - Turns away everyone who is not a Merchant, with a special remark for Merchants who already
    went through the class once.
  - Lectures on Increase Weight Limit, Item Appraisal, Mammonite, Discount, Over Charge, Push Cart
    and Vending in that order, advancing the training quest after each lesson.
  - Rewards each lesson with experience, or with an item when the player already learned the
    subject of the next lecture, and pays extra for students who went beyond the assignment.
  - Sends the student to Prontera to buy ten Red Potions at the cheapest price and judges the
    purchase on return.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "alberta_in", x: 70, y: 51, dir: 5, sprite: 98, name: "Guarnien", scope: :shared}
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FSexmes
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Guarnien]")

    if merchant?(ctx) do
      lecture(ctx, get_char_var(ctx, :tu_merchant, 0))
    else
      turn_away(ctx)
    end
  end

  defp merchant?(ctx), do: Rathena.job_id(class(ctx)) == Rathena.job_id(:merchant)

  defp turn_away(ctx) do
    ctx =
      ctx
      |> mes("Hello stranger.")
      |> mes("I wish I could")
      |> mes("offer you help")
      |> mes("on your adventures...")
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "However, what I have to teach would only benefit Merchants. Trading and money making are my areas of expertise. If you have any Merchant friends, send them to me."
      )

    ctx =
      if Rathena.job_id(class(ctx)) == Rathena.job_id(:merchant_high) do
        ctx
        |> next()
        |> mes("[Guarnien]")
        |> mes(
          "Technically, yes, you're a Merchant, but I know an expert when I see one. You've been through the Merchant life before, I can tell!"
        )
      else
        ctx
      end

    close(ctx)
  end

  defp lecture(ctx, 17), do: concluding_advice(ctx)
  defp lecture(ctx, step) when step in [15, 16], do: vending_lesson(ctx, step)
  defp lecture(ctx, step) when step in [13, 14], do: push_cart_lesson(ctx, step)
  defp lecture(ctx, step) when step in [11, 12], do: over_charge_lesson(ctx, step)
  defp lecture(ctx, 10), do: scammed_red_potions(ctx)
  defp lecture(ctx, 9), do: cheap_red_potions(ctx)
  defp lecture(ctx, step) when step in [6, 7, 8], do: market_research_hint(ctx)
  defp lecture(ctx, 5), do: send_to_prontera(ctx)
  defp lecture(ctx, step) when step in [3, 4], do: discount_lesson(ctx, step)
  defp lecture(ctx, 2), do: mammonite_lesson(ctx)
  defp lecture(ctx, 1), do: increase_weight_limit_lesson(ctx)
  defp lecture(ctx, _step), do: offer_lessons(ctx)

  defp concluding_advice(ctx) do
    ctx
    |> mes("We can't even begin")
    |> mes("to fathom the number")
    |> mes("of markets and people")
    |> mes("out there in this wide,")
    |> mes("wide world of ours.")
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "All of them are possible customers and business partners. Of course, it'll be up to you to meet them."
    )
    |> mes("If you can be sincerely kind to everyone that you meet, you'll")
    |> mes("have no problem.")
    |> close()
  end

  defp vending_lesson(ctx, step) do
    vending_level = getskilllv(ctx, 41)
    ctx = set_local(ctx, :chk_vend, vending_level)

    case step do
      15 -> first_vending_lecture(ctx, vending_level)
      16 -> vending_follow_up(ctx, vending_level)
    end
  end

  defp first_vending_lecture(ctx, vending_level) do
    ctx =
      ctx
      |> mes("I believe it's time")
      |> mes("for my final lecture.")
      |> mes("I'll discuss the definitive")
      |> mes("skill of the Merchant: ^871F78Vending^000000. Please listen carefully.")
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "The Vending skill is an active skill which allows you to open your own shop where you stand. Vending allows you to do real business with other people."
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes("However, you can only vend items that are stored in your PushCart,")
      |> mes("so you'll need one of those. The maximum price you can set for")
      |> mes("each item is 99,990,000 Zeny.")
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "Basically, you've got to learn the Push Cart skill first before you can learn the Vending skill."
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "The higher the level of the Vending skill, the more items you can vend at one time. Vending is mastered at Skill Level 10."
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes("Level 1 Vending allows you")
      |> mes(
        "to vend a total of 3 items at one time. Each time you level up the Vending skill, the total number of items you can vend will"
      )
      |> mes("increase by one.")
      |> next()
      |> mes("[Guarnien]")

    cond do
      vending_level > 3 and vending_level < 10 ->
        ctx
        |> mes(
          "But I see that you must already know that, huh? Well, seeing as you're so clever, I think you've earned this little prize~"
        )
        |> getexp(186, 60)
        |> completequest(8239)
        |> finish_vending_lesson()

      vending_level == 10 ->
        ctx
        |> mes(
          "But it looks like I just put my foot in my mouth. I'm sorry, I didn't notice that you already mastered the Vending skill..."
        )
        |> next()
        |> mes("[Guarnien]")
        |> mes("You're such an")
        |> mes("excellent student!")
        |> mes("Please, take this")
        |> mes("little reward for")
        |> mes("all your efforts~")
        |> getexp(199, 69)
        |> completequest(8239)
        |> finish_vending_lesson()

      true ->
        ctx
        |> mes(
          "For your final assignment, I will ask you to learn the Vending skill up to Skill Level 4. Of course, once you do, I'll give you a little reward. I'll be waiting, so do your best~"
        )
        |> set_char_var(:tu_merchant, 16)
        |> erasequest(8239)
        |> setquest(8240)
        |> close()
    end
  end

  defp vending_follow_up(ctx, vending_level) do
    ctx =
      ctx
      |> mes("So...")
      |> mes("How much have")
      |> mes("you learned")
      |> mes("about Vending?")
      |> next()
      |> mes("[Guarnien]")

    cond do
      vending_level > 3 and vending_level < 10 ->
        ctx
        |> mes("Excellent!")
        |> mes("You've taught yourself well. Here, you've earned this little reward~")
        |> getexp(186, 43)
        |> completequest(8240)
        |> finish_vending_lesson()

      vending_level == 10 ->
        ctx
        |> mes(
          "Oh, I see that you're very serious about being a Merchant. I'm proud that you've managed to master this skill! Here, you deserve this reward!"
        )
        |> getexp(199, 69)
        |> completequest(8240)
        |> finish_vending_lesson()

      true ->
        ctx
        |> mes("Hmm...")
        |> mes(
          "Haven't learned Level 4 Vending yet, huh? Just keep in mind that being able to vend things is one"
        )
        |> mes("of the defining characteristics of being a Merchant!")
        |> close()
    end
  end

  defp finish_vending_lesson(ctx) do
    ctx
    |> set_char_var(:tu_merchant, 17)
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "Ah, now you have mastered the fundamentals of the Merchant class. Just keep practicing the basic principles, like researching the market for item prices, and you should be fine."
    )
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "Although everything we do is for money, never forget customer needs and always sell your products at a suitably fair price. Otherwise, no one may buy your goods!"
    )
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "Well, there's nothing more I can teach you for now. Go out into the world and make your mark as a Merchant."
    )
    |> next()
    |> mes("[Guarnien]")
    |> mes("And feel free to")
    |> mes("visit me whenever")
    |> mes("the mood strikes you.")
    |> mes("Good luck to you~")
    |> close()
  end

  defp push_cart_lesson(ctx, step) do
    cart_level = getskilllv(ctx, 39)
    ctx = set_local(ctx, :chk_cart, cart_level)

    case step do
      13 -> first_push_cart_lecture(ctx, cart_level)
      14 -> push_cart_follow_up(ctx, cart_level)
    end
  end

  defp first_push_cart_lecture(ctx, cart_level) do
    ctx =
      ctx
      |> mes("Now to talk about")
      |> mes(
        "^871F78Push Cart^000000. First off, you need to know Level 5 Increase Weight Limit before you can even learn the Push Cart skill."
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes("Push Cart can be mastered at")
      |> mes(
        "Skill Level 10. This skill allows you to carry a Push Cart with you. You can carry a maximum of 100 different kinds of items that weigh less than 8,000."
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "As you can see, this skill is an advanced form of the Increase Weight Limit skill. You can procure a PushCart from most Kafra Ladies for a certain fee."
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "Once you have rented a Cart, you can hold on to it so long as you don't take it off. The disadvantage to using a PushCart is that your movement speed is reduced to"
      )
      |> mes("almost half! Horrible, isn't it?")
      |> next()
      |> mes("[Guarnien]")
      |> mes("Fortunately, when you increase")
      |> mes(
        "the level of the Push Cart skill, your movement speed will slowly be restored. With Push Cart Level 10, a PushCart won't slow you"
      )
      |> mes("down at all!")
      |> next()
      |> erasequest(8237)
      |> set_local(:chk_cart, getskilllv(ctx, 39))
      |> mes("[Guarnien]")

    cond do
      cart_level > 3 and cart_level < 10 ->
        ctx
        |> mes(
          "Ah, and I see that you've been focusing on learning Push Cart. Although you might still have a problem with your movement"
        )
        |> mes("speed, it shouldn't be a big deal.")
        |> mes("Well done~")
        |> getexp(162, 52)
        |> setquest(8239)
        |> finish_push_cart_lesson()

      cart_level == 10 ->
        ctx
        |> mes("Wonderful! You've already")
        |> mes("mastered the Push Cart skill.")
        |> mes("You truly deserve a little bit of a reward~")
        |> getexp(186, 60)
        |> setquest(8239)
        |> finish_push_cart_lesson()

      true ->
        ctx
        |> mes("For now, why don't")
        |> mes("you learn the Push Cart")
        |> mes("skill up to Level 4? Once")
        |> mes("you do that, I can go on to")
        |> mes("my next lecture.")
        |> set_char_var(:tu_merchant, 14)
        |> setquest(8238)
        |> close()
    end
  end

  defp push_cart_follow_up(ctx, cart_level) do
    ctx =
      ctx
      |> mes("So, have you")
      |> mes("learned Push Cart up")
      |> mes("to Level 4 like I asked?")
      |> next()
      |> mes("[Guarnien]")

    cond do
      cart_level > 3 and cart_level < 10 ->
        ctx
        |> mes("Well done~")
        |> mes("You've been a very")
        |> mes("cooperative student.")
        |> mes("You deserve a little")
        |> mes("reward for your effort~")
        |> getexp(162, 52)
        |> erasequest(8238)
        |> setquest(8239)
        |> finish_push_cart_lesson()

      cart_level == 10 ->
        ctx
        |> mes("Excellent!")
        |> mes("You've actually went above and beyond mastered the Push Cart skill. Great work!")
        |> getexp(186, 60)
        |> erasequest(8238)
        |> setquest(8239)
        |> finish_push_cart_lesson()

      true ->
        ctx
        |> mes("Still not there, huh?")
        |> mes("Well, remember that you need")
        |> mes("Level 5 Increase Weight Limit before you can learn the Push")
        |> mes("Cart skill. I hope that helps.")
        |> close()
    end
  end

  defp finish_push_cart_lesson(ctx) do
    ctx
    |> set_char_var(:tu_merchant, 15)
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "Next time, I'll talk about the skill that sets Merchants apart from all the other classes: ^871F78Vending^000000. So don't miss it!"
    )
    |> close()
  end

  defp over_charge_lesson(ctx, step) do
    over_charge_level = getskilllv(ctx, 38)
    ctx = set_local(ctx, :chk_over, over_charge_level)

    case step do
      11 -> first_over_charge_lecture(ctx, over_charge_level)
      12 -> over_charge_follow_up(ctx, over_charge_level)
    end
  end

  defp first_over_charge_lecture(ctx, over_charge_level) do
    ctx =
      ctx
      |> mes("Ah, ready to")
      |> mes("learn already,")
      |> mes("are you? Alright,")
      |> mes("let me tell you")
      |> mes("about ^871F78Over Charge^000000.")
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "Like Discount, Over Charge is a Passive skill that can be mastered at Skill Level 10. Therefore, it doesn't require SP to use it."
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "Over Charge allows you to sell items to NPC shops for more Zeny. The higher your Over Charge Skill Level, the more Zeny you'll receive for items sold to NPCs."
      )
      |> next()
      |> mes("[Guarnien]")
      |> erasequest(8235)
      |> set_local(:chk_over, getskilllv(ctx, 38))

    cond do
      over_charge_level > 3 and over_charge_level < 10 ->
        ctx
        |> mes(
          "Ah, you've already learned Level 4 Over Charge. Perfect! Let me give you a little reward~"
        )
        |> getexp(126, 27)
        |> setquest(8237)
        |> finish_over_charge_lesson()

      over_charge_level == 10 ->
        ctx
        |> mes(
          "Amazing! You've already mastered the Over Charge skill! You must have wanted this reward badly~"
        )
        |> getexp(142, 33)
        |> setquest(8237)
        |> finish_over_charge_lesson()

      true ->
        ctx
        |> mes(
          "Personally, I think you should learn this skill for sure! For your next assignment, learn Over Charge up to Level 4. It shouldn't be too difficult to do."
        )
        |> set_char_var(:tu_merchant, 12)
        |> setquest(8236)
        |> next()
        |> mes("[Guarnien]")
        |> mes("Once you do that,")
        |> mes("we can talk about")
        |> mes("more advanced stuff.")
        |> mes("Do your best~")
        |> close()
    end
  end

  defp over_charge_follow_up(ctx, over_charge_level) do
    ctx =
      ctx
      |> mes("So...")
      |> mes("How is it going")
      |> mes("with learning that")
      |> mes("^871F78Over Charge^000000 skill?")
      |> next()
      |> mes("[Guarnien]")

    cond do
      over_charge_level > 3 and over_charge_level < 10 ->
        ctx
        |> mes("Nice work!")
        |> mes("I can tell that")
        |> mes("you've done just")
        |> mes("as I asked. Please,")
        |> mes("take this little reward~")
        |> getexp(126, 27)
        |> erasequest(8236)
        |> setquest(8237)
        |> finish_over_charge_lesson()

      over_charge_level == 10 ->
        ctx
        |> mes("Whoa...")
        |> mes("You actually")
        |> mes("mastered Over Charge?")
        |> mes("Most impressive! You deserve a small reward for your work!")
        |> getexp(142, 33)
        |> erasequest(8236)
        |> setquest(8237)
        |> finish_over_charge_lesson()

      true ->
        ctx
        |> mes("Mm? You haven't")
        |> mes("learned Over Charge")
        |> mes("up to Skill Level 4 yet?")
        |> mes(
          "There's no rush, but I won't be able to lecture on anything until you finish this little task."
        )
        |> close()
    end
  end

  defp finish_over_charge_lesson(ctx) do
    ctx
    |> set_char_var(:tu_merchant, 13)
    |> next()
    |> mes("[Guarnien]")
    |> mes("Next time, I'll discuss the")
    |> mes(
      "Push Cart skill. Be ready for this lecture, as Push Cart is one of the more important skills for a Merchant."
    )
    |> close()
  end

  defp scammed_red_potions(ctx) do
    ctx
    |> mes("Let me see those")
    |> mes("Red Potions. Now,")
    |> mes("how much did you")
    |> mes("pay for these...?")
    |> next()
    |> mes("[Guarnien]")
    |> mes("Ah...!")
    |> mes("It looks like...")
    |> mes("You were scammed!")
    |> mes("D-don't worry, though,")
    |> mes("I won't tell anybody.")
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "Oh well, it happens even to the best of us. Just think of this as an invaluable learning experience."
    )
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "Now, why don't you go to Prontera and try to buy 10 Red Potions from an NPC for the cheapest price again?"
    )
    |> set_char_var(:tu_merchant, Enum.random(6..8))
    |> close()
  end

  defp cheap_red_potions(ctx) do
    ctx
    |> mes("Let me see those")
    |> mes(
      "Red Potions. Ah, it seems you researched the market and bought the cheapest ones! Great work!"
    )
    |> set_char_var(:tu_merchant, 11)
    |> changequest(8234, 8235)
    |> getexp(112, 22)
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "Alright, next time, we'll talk about the skill that you can learn after knowing how to Discount:"
    )
    |> mes("^871F78Over Charge^000000.")
    |> close()
  end

  defp market_research_hint(ctx) do
    ctx
    |> mes("Hmm...")
    |> mes("You'll find some NPCs")
    |> mes("selling 10 Red Potions")
    |> mes("in Prontera. Your task")
    |> mes("is to buy the potions")
    |> mes("for the cheapest price.")
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "First, you'll probably want to research the market price for Red Potions. And always, be careful of scammers and cheats!"
    )
    |> close()
  end

  defp send_to_prontera(ctx) do
    ctx
    |> mes("Alright...")
    |> mes(
      "I've given it some thought and I've come up with a little challenge for you. Bring me... 10 Red Potions!"
    )
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "It's not too hard, but the stipulation I'm adding is that you've got to find the merchant selling Red Potions for the cheapest price."
    )
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "So first, you'll need to research the market price for Red Potions. Also, be careful of scammers! If the price is too good to be true, it usually is."
    )
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "Ha ha ha, let me make your goal a bit less confusing. You will need to buy 10 Red Potions from an NPC in Prontera."
    )
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "Prontera's a bit far from here, isn't it? I'll just use this Kafra Warp-- Mahnsoo has a bunch for"
    )
    |> mes("some reason --to send you there right now. Get ready...!")
    |> next()
    |> set_char_var(:tu_merchant, Enum.random(6..8))
    |> changequest(8233, 8234)
    |> warp("prontera", 155, 46)
  end

  defp discount_lesson(ctx, step) do
    discount_level = getskilllv(ctx, 37)
    ctx = set_local(ctx, :chk_disc, discount_level)

    case step do
      3 -> first_discount_lecture(ctx, discount_level)
      4 -> discount_follow_up(ctx, discount_level)
    end
  end

  defp first_discount_lecture(ctx, discount_level) do
    ctx =
      ctx
      |> mes("Ah, you're back!")
      |> mes("Now, I was going")
      |> mes("to tell you about")
      |> mes("the Discount skill, right?")
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "The ^871F78Discount^000000 skill allows you to buy items at lower prices from NPC shops. It is a ^871F78Passive Skill^000000 which is always in effect and does not consume SP."
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes("The Discount skill is")
      |> mes(
        "mastered at ^871F78Level 10^000000. The higher the skill level, the less you have to pay for items at NPC shops."
      )
      |> next()
      |> mes("[Guarnien]")

    cond do
      discount_level > 3 and discount_level < 10 ->
        ctx
        |> mes("Oooh, good work.")
        |> mes("I see that you've")
        |> mes("raised your Discount")
        |> mes("to Level 4 already.")
        |> mes("Here, take this")
        |> mes("small reward~")
        |> getexp(83, 11)
        |> erasequest(8231)
        |> setquest(8233)
        |> finish_discount_lesson()

      discount_level == 10 ->
        ctx
        |> mes("Incredible!")
        |> mes(
          "You've actually mastered the Discount skill! You're such a great student. You deserve a bit of a reward!"
        )
        |> getexp(97, 18)
        |> erasequest(8231)
        |> setquest(8233)
        |> finish_discount_lesson()

      true ->
        ctx
        |> mes(
          "Alright! Now, in order to become closer towards becoming a true Merchant, I want you to learn the Discount skill up to Level 4."
        )
        |> next()
        |> mes("[Guarnien]")
        |> mes("It'd be nicer if you could")
        |> mes(
          "master it, but you might be more interested in devoting your time to other skills."
        )
        |> next()
        |> mes("[Guarnien]")
        |> mes(
          "Still, you can't ignore the fact that bargaining is an essential skill for a Merchant! Come back to me when you're ready~"
        )
        |> set_char_var(:tu_merchant, 4)
        |> erasequest(8231)
        |> setquest(8232)
        |> close()
    end
  end

  defp discount_follow_up(ctx, discount_level) do
    ctx =
      ctx
      |> mes(
        "So, how is it going with learning the Discount skill? Like I always say, if you can't make a bargain, you can't be a Merchant!"
      )
      |> next()
      |> mes("[Guarnien]")

    cond do
      discount_level > 3 and discount_level < 10 ->
        ctx
        |> mes("Ah, you've learned")
        |> mes("how to use the Discount skill")
        |> mes("well enough. Good, here's a little reward for your hard work~")
        |> getexp(83, 11)
        |> erasequest(8232)
        |> setquest(8233)
        |> finish_discount_lesson()

      discount_level == 10 ->
        ctx
        |> mes("Incredible!")
        |> mes(
          "You've actually mastered the Discount skill! You're such a great student. You deserve a bit of a reward!"
        )
        |> getexp(97, 18)
        |> erasequest(8232)
        |> setquest(8233)
        |> finish_discount_lesson()

      true ->
        ctx
        |> mes("Not yet, huh?")
        |> mes(
          "Well, you should be able to reach that goal soon. After all, it's one of the basics of being a Merchant!"
        )
        |> close()
    end
  end

  defp finish_discount_lesson(ctx) do
    ctx
    |> set_char_var(:tu_merchant, 5)
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "Alright, my next lesson will hopefully offer you a bit more of a challenge. Come back when you think you're ready, alright?"
    )
    |> close()
  end

  defp mammonite_lesson(ctx) do
    ctx =
      ctx
      |> mes(
        "Ah, you've come back to learn more. Let's see, what was I going to tell you about... Right, Mammonite!"
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "^871F78Mammonite^000000 is a skill that lets you greatly damage targets with Zeny. Money really is power!"
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "The upside is that it inflicts great damage and only uses a little SP. However, the downside is that it will also consume your Zeny!"
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "So if you use this skill too often, you might end up bankrupt! So be really careful. Also, as the Skill Level for Mammonite increases, so does the attack strength and Zeny consumption."
      )
      |> next()
      |> mes("[Guarnien]")

    mammonite_level = getskilllv(ctx, 42)
    ctx = set_local(ctx, :chk_mam, mammonite_level)

    if mammonite_level > 3 and mammonite_level < 10 do
      ctx
      |> mes(
        "Ah, I see that you've already tried this skill. How much money have you wasted using Mammonite? Not too much, I hope."
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "Well, since you're still green, I feel awfully sorry if you've wasted Zeny. Why don't you take this as compensation?"
      )
      |> set_char_var(:tu_merchant, 3)
      |> erasequest(8230)
      |> setquest(8231)
      |> getexp(70, 12)
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "Okay. Now I think we're ready for me to discuss the ^871F78Discount^000000 skill. Come back when you'd like me to tell you more about it, okay?"
      )
      |> close()
    else
      ctx
      |> mes(
        "Okay. Now I think we're ready for me to discuss the ^871F78Discount^000000 skill. Come back when you'd like me to tell you more about it, okay?"
      )
      |> set_char_var(:tu_merchant, 3)
      |> erasequest(8230)
      |> setquest(8231)
      |> close()
    end
  end

  defp increase_weight_limit_lesson(ctx) do
    ctx =
      ctx
      |> mes("So...")
      |> mes("Did you learn the")
      |> mes("Increase Weight Limit")
      |> mes("skill up to Level 4")
      |> mes("like I asked?")
      |> next()
      |> mes("[Guarnien]")

    weight_limit_level = getskilllv(ctx, 36)
    ctx = set_local(ctx, :chk_soji, weight_limit_level)

    if weight_limit_level > 3 and weight_limit_level < 10 do
      ctx
      |> mes(
        "Ah. I can tell that you have. Not bad! By now you should be able to learn the ^871F78Discount^000000 skill, but I'll teach you about that later."
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "There are a few other basic skills which you can learn right away that I'll talk about first. Let's not rush~"
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "First, there's the ^871F78Item Appraisal^000000 skill. This ability, once you've learned it, allows you to ^871F78identify unknown items^000000."
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "This skill works exactly like a ^871F78Magnifier^000000, so you won't have to spend any Zeny on them. Also, this skill is mastered at ^871F78Level 1^000000."
      )
      |> next()
      |> reward_item_appraisal()
    else
      ctx
      |> mes("No? That's fine.")
      |> mes("But I can't teach you")
      |> mes(
        "much more if you can't grasp these simple basics, so hurry and learn those skills, okay?"
      )
      |> close()
    end
  end

  defp reward_item_appraisal(ctx) do
    if Rathena.truthy?(getskilllv(ctx, 40)) do
      ctx
      |> mes("[Guarnien]")
      |> mes(
        "I see in your eyes that you've already learned to appraise items. Haha, although having that knowledge is reward in itself, let me give you something extra!"
      )
      |> set_char_var(:tu_merchant, 2)
      |> erasequest(8229)
      |> setquest(8230)
      |> getexp(58, 11)
      |> give_item(1351, 1)
      |> next()
      |> mes("[Guarnien]")
      |> mes("Alright, next time")
      |> mes(
        "I'll talk about the Mammonite skill. For now, let me take a little bit of a break from all of this arduous lecture. ^666666*Whew!*^000000"
      )
      |> close()
    else
      ctx
      |> mes("Alright, next time")
      |> mes(
        "I'll talk about the Mammonite skill. For now, let me take a little bit of a break from all of this arduous lecture. ^666666*Whew!*^000000"
      )
      |> set_char_var(:tu_merchant, 2)
      |> erasequest(8229)
      |> setquest(8230)
      |> close()
    end
  end

  defp offer_lessons(ctx) do
    {ctx, choice} =
      ctx
      |> mes(
        "You've just started out as a Merchant, haven't you? How would you like to learn the fundamentals of business from an experienced colleague?"
      )
      |> next()
      |> select(["Sure!", "I'll make it on my own!"])

    case choice do
      1 -> accept_student(ctx)
      _ -> decline_student(ctx)
    end
  end

  defp accept_student(ctx) do
    if getskilllv(ctx, 36) < 4 do
      {ctx, greeting} =
        ctx
        |> set_char_var(:tu_merchant, 1)
        |> setquest(8229)
        |> mes("[Guarnien]")
        |> FSexmes.call(["Atta girl~!", "Atta boy~!"])

      ctx
      |> mes(greeting)
      |> mes("But first things first!")
      |> mes("You better learn the")
      |> mes("^871F78Increase Weight Limit^000000 skill!")
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "You can't really be a Merchant if you can't even carry around goods to sell. As you increase the level of this skill, you can carry around more items."
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes("Why don't you upgrade your")
      |> mes(
        "Increase Weight Limit skill up to Level 4? After that, we can talk more about becoming a true Merchant."
      )
      |> close()
    else
      ctx
      |> mes("[Guarnien]")
      |> mes("Great...!")
      |> mes(
        "Ah, and I see that you've learned the ^871F78Increase Weight Limit^000000 skill to at least Level 4. You're a real go-getter, aren't you?"
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes("Since your Increase Weight")
      |> mes(
        "Limit skill level is high enough, you must be able to see a new skill in your Skill Window: ^871F78Discount^000000!"
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "But we'll discuss the Discount skill later. There are a few other basic skills which you can learn right away that I'll talk about first. Let's not rush~"
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "First, there's the ^871F78Item Appraisal^000000 skill. This ability, once you've learned it, allows you to ^871F78identify unknown items^000000."
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes(
        "This skill works exactly like a ^871F78Magnifier^000000, so you won't have to spend any Zeny on them. Also, this skill is mastered at ^871F78Level 1^000000."
      )
      |> next()
      |> mes("[Guarnien]")
      |> start_after_introduction()
    end
  end

  defp start_after_introduction(ctx) do
    if Rathena.truthy?(getskilllv(ctx, 40)) do
      ctx
      |> mes(
        "I see in your eyes that you've already learned to appraise items. Haha, although having that knowledge is reward in itself, let me give you something extra!"
      )
      |> set_char_var(:tu_merchant, 2)
      |> erasequest(8229)
      |> setquest(8230)
      |> getexp(58, 11)
      |> give_item(1351, 1)
      |> next()
      |> mes("[Guarnien]")
      |> mes("Alright, next time")
      |> mes(
        "I'll talk about the Mammonite skill. For now, let me take a little bit of a break from all of this arduous lecture. ^666666*Whew!*^000000"
      )
      |> close()
    else
      ctx
      |> mes("Alright, next time")
      |> mes(
        "I'll talk about the Mammonite skill. For now, let me take a little bit of a break from all of this arduous study."
      )
      |> next()
      |> mes("[Guarnien]")
      |> mes("Oh...")
      |> mes("And I'll tell you")
      |> mes("more about the Discount")
      |> mes("skill later. I always manage")
      |> mes("to forget about that!")
      |> set_char_var(:tu_merchant, 2)
      |> erasequest(8229)
      |> setquest(8230)
      |> close()
    end
  end

  defp decline_student(ctx) do
    ctx
    |> mes("[Guarnien]")
    |> mes("On your own?")
    |> mes("Hahaha, that's the spirit!")
    |> mes(
      "But still, the advice I'm giving is free. It couldn't hurt to give what I say a little bit of thought."
    )
    |> next()
    |> mes("[Guarnien]")
    |> mes(
      "Well, if you ever change your mind, stop by and talk to me anytime. And as a Merchant, you should know that free advice is the best!"
    )
    |> close()
  end
end
